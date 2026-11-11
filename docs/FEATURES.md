# 功能交付清单

本文件按**用户视角的功能模块**回答三个问题：这块能做什么、卡在哪几处、做到什么程度算做完。

与七张对照表的分工写死一句：**七表回答「上游有什么、本地接了没有」**（逐行 1172 条，见 [ZIP 兼容总账](parity/STATUS.md)），**本文件回答「用户能用什么」**。两者不重复——本文件不抄逐行状态，只在需要时指到具体 `文件:行`。

## 六模块与优先级

顺序即实施顺序，由使用者确定；与 [项目队列](PROJECT.md) 的编号一一对应。

| 顺序 | 模块 | 现在能不能用 | 主要入口 | 明细 |
| --- | --- | --- | --- | --- |
| 1 | 书架 | 本地 TXT/EPUB 的完整闭环可用；在线来源与书单导入导出仍空 | `pages/BookshelfPage.ets`、`pages/BookInfoPage.ets` | 本文第一章 |
| 2 | 阅读器 | 分页与滚动两种模式、目录、书内搜索、主题、替换净化可用；朗读入口未接 | `pages/ReaderPage.ets`（7871 行）、`pages/ReaderSettingsPage.ets`（3954 行） | 本文第二章 |
| 3 | 朗读 | **不能**：零音频能力，两个朗读页全是占位 | `pages/ReaderAloudSettingsPage.ets`、`pages/AppReadAloudSettingsPage.ets` | 本文第三章 |
| 4 | 阅读记录 | 概览、热力图、合并、扫描修复、清空都可用 | `pages/ProfileSubPages.ets:3014`-`:3873`、`pages/ReadRecordOverviewPage.ets` | 本文第四章 |
| 5 | 外观 | 主题包、日夜模式、自定义配色可用；启动图标是平台限制、主题风格与多窗布局上游本身不接 | `pages/ThemeSettingsPage.ets`、`pages/ThemeManagePage.ets` | 本文第五章 |
| 6 | 备份与恢复 | 28 类全部双向通，含 WebDAV 上传下载；旧版数据导入与系统目录选择仍空 | `pages/AppBackupSettingsPage.ets`、`data/BackupRepository.ets`（3773 行） | 本文第六章 |

## 一、书架

### 1.1 能做什么

今天在设备上能走通的完整链路：

- **导入本地书**：系统文件选择器，只列 `.txt` 与 `.epub`（`data/BookRepository.ets:437` 的 `fileSuffixFilters`）。同一本书再导入走「更新目录」分支，不新增第二条记录（`pages/Index.ets` 的 `importLocalBook`，判重键是 `bookUrl`）。
- **书架展示**：分组页签 / 隐藏页签 / 文件夹三种样式（`pages/BookshelfPage.ets:1118`、`:1125`、`:1142`），竖屏与横屏各有列表/网格两档，卡片可显示简介、最新章节、章节角标与阅读进度。
- **排序**：六个排序档加正逆序（`model/BookGroup.ets:39` 的 `BOOK_SORT_OPTIONS`，比较逻辑在 `data/BookshelfSort.ets:11`）；分组自己设了排序档时覆盖书架全局，与上游 `sortBooks()` 取值优先级一致（`BookshelfPage.ets:255`-`:257`）。
- **分组管理**：新建、改名、显隐、删除、换封面、拖动改分组顺序（回调见 `BookshelfPage.ets:114`-`:133`，面板在 `GroupManagerSheet` `:542`）。
- **搜索**：书名或作者子串过滤（`BookshelfPage.ets:1109` 的输入框，过滤逻辑 `:242`-`:259`）。
- **更新目录**：菜单项「更新目录」走 `onRefreshToc`（`BookshelfPage.ets:1050`-`:1051`）。
- **布局设置**：30 余项，含封面宽度上限、列表封面宽度、标题行数/字号/居中/阴影、卡片底色日夜两套、列表分隔线与简介位置、快速滚动条（`LayoutSheetContent` `:818` 起）。
- **书籍详情**：编辑元数据、查看目录、阅读记录面板、移出书架或删除缺正文记录（`pages/BookInfoPage.ets:265`-`:279`）。
- **长按**：长按分组卡片进编辑面板，长按书籍卡片进详情（`BookshelfPage.ets:1087`、`:1281`）。

### 1.2 卡在这几处

全部集中在书架右上的「更多」菜单与书籍详情的动作行，都是**入口在、后端与服务不在**：

| 菜单项 | 位置 | 缺什么 |
| --- | --- | --- |
| 远程书籍 | `BookshelfPage.ets:1044` | 远程书库的 URL 拉取与解析（上游 `ui/book/import/remote/RemoteBookScreen.kt`） |
| 添加网址 | `BookshelfPage.ets:1057` | 同上，从 URL 直接建书 |
| 选择模式 | `BookshelfPage.ets:1059` | 批量选择与批量删除/分组（上游 `ui/book/manage/BookshelfManageScreen.kt`） |
| 书架管理 | `BookshelfPage.ets:1061` | 同上，书架管理的独立页 |
| 导出书单 | `BookshelfPage.ets:1063` | 书单 JSON 生成与落盘 |
| 导入书单 | `BookshelfPage.ets:1065` | 书单解析与合并 |
| 日志 | `BookshelfPage.ets:1067` | 应用日志页（依赖日志缓冲） |
| 换源 | `BookInfoPage.ets:271` | 在线书源；文案写的「将在 P5 接入」是历史排期号，现由本文的模块顺序取代 |
| 书籍分享 | `BookInfoPage.ets:349` | 分享面板 |
| 更多操作 | `BookInfoPage.ets:350` | 详情页溢出菜单 |

另有**三处「看着能用、其实不生效」**，比纯占位更容易被误判：

- **手动排序档可以选，但不能拖**：`Book_SORT_OPTIONS` 的第 4 档「手动排序」按 `book.order` 比较（`data/BookshelfSort.ets:45`-`:47`），但全仓没有任何拖动改 `order` 的入口（`onItemDrag` / `ItemDragInfo` 零命中）。选中该档只会按导入顺序显示。
- **下拉刷新只是存字段**：分组编辑里的「下拉刷新」开关写的是 Android 兼容字段 `enableRefresh`，界面自己标了「仅保存 Android 兼容字段；当前不控制实际更新」（`BookshelfPage.ets:497`）。
- **缺正文的记录**：书目存在但正文文件丢失时卡片走详情页而非阅读页（`BookshelfPage.ets:1275`-`:1279`），详情页给的是「移出缺正文记录」而不是「补正文」。

### 1.3 算做完的判据

第 1 章收口的标准是下面每一项都能在设备上一次走通，且中途不出现「尚未迁移」提示：

- [ ] 导入一本 TXT 与一本 EPUB，书架出现两条卡片，封面、书名、作者、章节数正确。
- [ ] 同一本再导入一次，提示已更新，书架仍是一条。
- [ ] 三种分组样式各切一遍，页签/文件夹/隐藏三态都能回到书架且筛选不丢。
- [ ] 新建分组、改名、换封面、拖到另一个位置、删除，五步都生效且重启后保持。
- [ ] 六个排序档各选一次，顺序与预期一致；切到「手动排序」后**能拖动改序并持久化**（当前缺，见 1.2）。
- [ ] 搜索框输入书名片段与作者片段，均能过滤；清空后恢复全量。
- [ ] 布局设置里改封面宽度、标题居中、卡片底色，书架立即变化，重启后保持。
- [ ] 「更新目录」对已导入的书可用，章节数与最新章节变化。
- [ ] 长按书籍进详情，元数据编辑保存后书架卡片同步刷新。
- [ ] 菜单里七项在线/书单/日志入口，要么接通，要么保持明确的未迁移提示（不能静默失败）。

### 1.4 验收记录

本章尚无逐项设备验收记录。设备截图与命令行输出按 [验证记录](VALIDATION.md) 的格式补记，不要写在本节。

## 二、阅读器

### 2.1 能做什么

- **两种阅读形态**：分页与滚动。翻页动画六档在 `reader/ReaderCanvasSurface.ets:31` 的 `ReaderTransitionMode` 里齐全（覆盖/滑动/仿真/滚动/淡入淡出/无动画），顺序与上游 `GlobalThemePage.kt:353-360` 一致。
- **排版**：字号 5–50 逐级可调、行距/段距/首行缩进/左右边距、六种对齐、正文与标题可分别设字体（`reader/ReaderTextLayoutEngine.ets:48` 的 `ReaderTextLayoutStyle`）。字体文件可以导入并注册（`ReaderFontRepository.importFont`，`pages/ReaderSettingsPage.ets:2005`），也支持导入整个目录批量注册（`:2019`）。
- **目录**：四个页签——信息 / 目录 / 书签 / 笔记（`pages/CatalogPage.ets:270` 的 `getTabLabel`），章节树支持卷与层级（`reverseTocHierarchy` `:207`），当前章自动滚到可见（`hasAutoScrolledCurrentChapter` `:97`）。
- **书内搜索**：全文或正则两种模式，支持替换模式、只搜本书历史（`pages/ReaderSearchPage.ets:50`-`:57` 的七个状态位），结果上限 200 条，遍历章节带进度显示（`:213` 的 `BookRepository.forEachChapter`）。
- **书签与笔记**：下滑添加/取消书签（`swipeToAddBookmark`）、自定义书签角标图片与大小（`bookmarkBadgeImage`/`bookmarkBadgeSize`）、七种标记效果与 16 色预设（`pages/ReaderMarkingEditor.ets:8`-`:22`），编辑与备注在 `ReaderMarkingEditor`（532 行）。
- **替换净化**：规则在正文进入排版前生效，正则跑在 taskpool worker 里逐条计时，单条超时自动停用该规则并提示（`data/ReplaceRuleEngine.ets:1`-`:17`、应用在 `data/BookRepository.ets:1863`）。
- **阅读设置**：四页签（全局 / 菜单 / 信息 / 更多），`pages/ReaderSettingsPage.ets:688` 的 `settingsContent`；含屏幕方向、沉浸式、护眼、翻页阈值、横屏双页、进度条行为、鼠标滚轮/音量键/长按翻页、文字选择与触感反馈、点击区域配置、自定义翻页按键等近百项。
- **自动阅读**：分页模式下按设定秒数自动翻页，滚动模式不画指示器（`pages/ReaderPage.ets:707`-`:724` 的状态与 `:1508` 的 `startAutoPageTurn`，计时器见 `:1482`）。
- **跳转与定位**：目录跳章、书内搜索跳定位、进度条拖拽（三档行为：页码/章节/整本）、翻页键。
- **阅读记录**：每章节读多久、读到哪、阅读会话都由 `onReadSessionStart/Pulse/Stop` 三回调上报（`pages/ReaderPage.ets:847`-`:849`）；记录本身见第四章。

### 2.2 卡在这几处

**一、朗读入口被切成两半，短按报错、长按能进设置页**

| 位置 | 现状 |
| --- | --- |
| `pages/ReaderPage.ets:3775` | 短按底栏「朗读」→ 弹「朗读播放尚未迁移」 |
| `pages/ReaderPage.ets:3831` | 长按底栏「朗读」→ 走 `onOpenReadAloud()`，能打开朗读设置页 |
| `Index.ets:7306` | `onOpenReadAloud` 已接线；但设置页里 13 处全是占位（见第三章） |

也就是说「进得去、用不了」。第三章做完之前，这条入口只能用长按进入查看。

**二、「更多」面板 23 项里 12 项未迁移**（`pages/ReaderPage.ets:85`-`:109` 的 `READER_MORE_ACTIONS`，`migrated: false` 的会在格子里显示「未迁移」角标，渲染在 `:7442`）

| 动作 | 行 | 缺什么 |
| --- | --- | --- |
| 书源自定义按钮 | `:86` | 在线书源 |
| 换源 | `:87` | 在线书源 |
| 刷新 | `:88` | 在线书源 |
| 离线缓存 | `:89` | 在线书源 |
| 听书下载 | `:90` | 朗读（第三章） |
| 删除 ruby 标签 | `:96` | EPUB 富文本处理 |
| 删除 h 标签 | `:97` | EPUB 富文本处理 |
| 模拟阅读 | `:102` | 模拟翻页演示 |
| 获取阅读进度 | `:103` | WebDAV 阅读进度同步（`servers.json` 已通，进度同步接口未接） |
| 覆盖阅读进度 | `:104` | 同上 |
| 日志 | `:108` | 应用日志页 |

另有 `:101` 的「翻页动画」标着 `migrated: false`，但点击**已经能用**——`:3964`-`:3966` 会打开六档单选框 `pageAnimMenuVisible`（`:7500`-`:7523`）。这是唯一一处「角标说未迁移、实际已实现」的错标，属文案 bug，不是功能缺失。

**三、阅读设置里的「未迁移」共 9 处**

| 位置 | 现象 |
| --- | --- |
| `pages/ReaderSettingsPage.ets:2276` | `showNotMigrated` 弹「此选项的原版 UI 已呈现；实际设置逻辑尚未迁移。」 |
| `:1062`、`:1079` | 菜单开关与滑杆的兜底分支，任何没写处理逻辑的条目都落到这里 |
| `:1612` | 朗读时允许音量键翻页 |
| `:1626` | 使用新版目录 |
| `:1631` | 自动切换书源 |
| `:1632` | 换源结果应用于全部书籍 |
| `:1636` | 朗读悬浮窗分离提醒 |
| `:1642` | 优化正文渲染 |
| `:3024` | 详情面板在 `getDetailChoices` 返回空时的兜底文案 |
| `:3920` | `MenuSettingOption` 组件在 `migrated: false` 时渲染的「尚未迁移」角标 |
| `:1562` | 页眉/页脚页的说明文字：「字体文件选择与颜色取色器尚未迁移」 |

其中 `:1562` 那句**已经过时**：字体导入在 `:2005`/`:2019` 是通的（`:2512`/`:2517` 两个按钮），页眉页脚取色走的是预设色板（`:1346`-`:1368` 的 `READER_INFO_COLOR_VALUES`），不是自由取色器。这句话应改成「取色为预设色板」。

**四、正文编辑类动作的边界**

「编辑内容」「反转内容」「重新分段」都能用（`:3943`-`:3955`），但都会改写当前章正文并落库，没有撤销入口。改错了只能靠重新导入或从备份恢复。

### 2.3 算做完的判据

- [ ] 导入一本 TXT，切到分页模式，六档翻页动画各翻 10 页，无卡顿、无残影、页边无露白。
- [ ] 同一本切到滚动模式，连续下滑跨过三章，正文不中断、页脚不压正文（见 `docs/KNOWN-ISSUES.md` 的 KI-REL1）。
- [ ] 字号从 5 拉到 50、行距与边距各拉到两端，正文不截断、不重叠，页眉页脚跟着重排。
- [ ] 目录切到「笔记」页签，新建一条划线与一条笔记，返回正文能看到标记，重启后仍在。
- [ ] 书内搜索一个必然出现的词，普通模式与正则模式各一次，点击结果能跳到准确位置。
- [ ] 一条替换规则启用后正文生效，禁用后恢复；给一条必然超时的坏正则，正文出现提示且该规则自动停用。
- [ ] 阅读设置四页签各滚到底，逐项点击，要么生效，要么给出明确「尚未迁移」提示（不能静默）。
- [ ] 自动阅读开起来，翻三页后手动打断，计时器归零不残留。
- [ ] 「更多」面板十二项未迁移动作各点一次，全部弹「此操作尚未迁移」，且**「翻页动画」不再显示未迁移角标**（当前错标，见 2.2）。
- [ ] 阅读过程中杀进程重开，回到上次读到的章与位置，页内偏移不丢。

### 2.4 验收记录

本章尚无逐项设备验收记录。已知的两条设备结论在 [已知问题](KNOWN-ISSUES.md)：KI-REL1（换章后位移被丢弃，已于 `c33d815` 修）、KI-REL5（浅色模式配色，未修）。

## 三、朗读

界面上的叫法是**朗读**——阅读页底栏那一格、`我的 → 设置 → 朗读设置`、页面标题 `Text('朗读设置')`（`pages/ReaderAloudSettingsPage.ets:35`、`pages/AppReadAloudSettingsPage.ets:30`、`pages/ProfileSubPages.ets:4161`）。技术上就是 TTS（Text To Speech），本章提到音源格式与系统能力时仍用 `TTS` 这个词（`httpTTS.json`、`@kit.CoreSpeechKit`）。界面上唯一出现「听书」的地方是底栏两项功能名：「听书界面」（`pages/ReaderAloudSettingsPage.ets:179`）与「听书下载」（`pages/ReaderPage.ets:90`），它们不是这一块的名字。

### 3.1 能做什么

**今天一件都做不了**：全仓没有任何音频播放或语音合成能力，两个朗读页的所有按钮都只弹提示。

- **进得去**：阅读页底栏的朗读键**长按**能打开朗读设置页（`pages/ReaderPage.ets:3831` 的 `longSelectBottomAction` → `onOpenReadAloud()` → `pages/Index.ets:6559` 的 `openReadAloudSettings()` → `:7731` 挂载 `ReaderAloudSettingsPage`）；`我的 → 设置 → 朗读设置` 也能进另一页（`pages/ProfileSubPages.ets:4161` → `pages/Index.ets:8505` 挂载 `AppReadAloudSettingsPage`）。
- **看得见**：朗读设置页界面是完整的——语速滑杆（`min:0 max:80`）、背景音乐音量滑杆（`0..100`）、「跟随系统」开关、定时行、底栏五格，都画出来了。
- **能滑不能存**：四个 `@State` 在 `pages/ReaderAloudSettingsPage.ets:4`-`:7`（`followSystem = true`、`rate = 40`、`musicVolume = 100`、`timerLabel = '关闭'`）。滑杆拖得动、开关翻得动，但值只停在内存里，`SliderChangeMode.End` 一到就弹「尚未迁移」，既不落盘也不影响任何播放（`:122`、`:141`、`:162`）。
- **数据层是真有的**：HTTP TTS 音源与朗读音色两张表、两个仓储都已落地（`data/HttpTtsRepository.ets` 208 行：`load` `:37`、`getAll` `:57`、`exportSources` `:62`、`importSources` `:67`、`save` `:94`；`data/ReadAloudVoiceRepository.ets` 296 行：`load` `:47`、`loadHttpVoices` `:71`、`exportVoices` `:86`、`importVoices` `:91`、`save` `:118`）。但它们**唯一的消费方是备份**（`data/BackupRepository.ets` 的写出与恢复分支），没有任何播放或界面代码读它们。

### 3.2 卡在这几处

**一、朗读设置页十三处占位，只有两格是真的**

页面 `pages/ReaderAloudSettingsPage.ets` 253 行，`onUnavailableAction` 共 14 处 = `:11` 属性声明 + 13 个调用点：

| 位置 | 控件 | 弹出的提示 |
| --- | --- | --- |
| `:48`、`:50`、`:52` | 三个 `AloudTransportButton`（上一句 / 暂停 / 停止） | 朗读播放尚未迁移 |
| `:62` | 「下一句」行 | 朗读播放尚未迁移 |
| `:94`、`:104` | 「上一章」「下一章」 | 朗读播放尚未迁移 |
| `:83` | 「定时」行 | 朗读定时功能尚未迁移 |
| `:122` | 背景音乐滑杆松手 | 背景音乐音量设置尚未迁移 |
| `:162` | 语速滑杆松手 | 朗读语速设置尚未迁移 |
| `:141` | 「跟随系统」开关 | 朗读系统设置尚未迁移 |
| `:176`、`:178`、`:180` | 底栏「后台」「设置」「听书界面」 | 后台朗读 / 朗读设置 / 听书界面尚未迁移 |

底栏五格（`AloudBottomAction`，`:172`-`:181`）里只有前两格真接线：主菜单走 `onOpenMainMenu()`，目录走 `onOpenCatalog()`。

**二、朗读设置总页七行全占位**

页面 `pages/AppReadAloudSettingsPage.ets` 只有 83 行，`onUnavailableAction` 共 8 处 = `:11` 属性声明 + 7 个 `AppReadAloudLinkRow`：

| 位置 | 行标题 | 副标题写的用途 |
| --- | --- | --- |
| `:35` | 角色声音池 | 管理角色声音池以及池内启用的音色 |
| `:39` | 背景音乐池 | 导入配乐文件，朗读时作为背景音乐播放 |
| `:43` | 变声器 | 管理音高、语速、混响与金属感预设 |
| `:47` | 朗读胶囊设置 | 设置正文胶囊的圆角、背景与头像形状位置 |
| `:51` | 朗读引擎与音色 | 配置朗读引擎并导入音色 |
| `:55` | 多角色识别 | 配置角色标记与声音池分隔符 |
| `:59` | 正则角色管理 | 按正文匹配更换音色或播放音效 |

**三、零音频能力**

`AVPlayer`、`AudioRenderer`、`avSession`、`media.create`、`audio.create`、`speechSynth`、`textToSpeech`、`@kit.MediaKit`、`@kit.AudioKit` 在 `entry/src/main/ets` 下**全部零命中**；`entry/include`、`entry/src/main/cpp` 都不存在，没有 native 音频代码；`entry/src/main/module.json5:13` 的权限只有 `ohos.permission.INTERNET` 一条。

**四、系统 TTS 能力现成，一行没接**

`@kit.CoreSpeechKit` 在 SDK 里就有（`sdk/default/hms/ets/kits/@kit.CoreSpeechKit.d.ts`，`@since 4.1.0(11)`），实体 `@hms.ai.textToSpeech` 提供 `createEngine`（`:40` 回调式 / `:57` Promise 式）、`setListener`（`:79`）、`speak(text, speakParams)`（`:98`，单次文本上限 10000 字符）、`listVoices`（`:111` / `:124`）、`stop`（`:135`）。项目基线 `compatibleSdkVersion` 与 `targetSdkVersion` 都是 `5.0.0(12)`，够用。**缺的只是接线。**

**五、与上游的规模差**

上游含 readaloud 路径的 `.kt` 有 143 个文件 / 38044 行，朗读相关 9 张表；本地只有 2 张（`httpTTS` 与 `read_aloud_voices`，`data/RdbSchema.ets:417`、`:436`）。角色声音池、背景音乐池、变声器、朗读胶囊、多角色识别、正则角色六块都没有对应表。

### 3.3 算做完的判据

分三档，前两档是「真的能读出声」，第三档是「对齐上游」：

**第一档：系统 TTS 能出声**

- [ ] 打开任意一本 TXT，长按底栏朗读键进设置页，点开始朗读后设备真的出声。
- [ ] 语速滑杆从最小拖到最大，朗读速度当场变化；退出再进，值还在（不是回到默认 40）。
- [ ] 点暂停立刻停声，点继续从停的地方接着读，不是从头。
- [ ] 朗读到章末自动进下一章，不需要手动点「下一章」。
- [ ] 朗读时切到别的页面，声音继续；回阅读页时正文高亮跟着朗读位置走。

**第二档：HTTP TTS 音源能用**

- [ ] 「我的 → 设置 → 朗读设置 → 朗读引擎与音色」能列出已导入的 HTTP TTS 音源（来自 `httpTTS` 表，不是空列表）。
- [ ] 导入一个 Android 备份 ZIP，其中的 `httpTTS.json` 与 `httpTtsVoices.json` 能出现在音源列表里并被选中朗读。
- [ ] 选一个需要网络的 HTTP TTS 音源朗读，断网时给出明确错误而不是静默无声。

**第三档：上游那七块不再是占位**

- [ ] `pages/AppReadAloudSettingsPage.ets` 的七行（`:35`、`:39`、`:43`、`:47`、`:51`、`:55`、`:59`）点进去都是真页面，不再走 `onUnavailableAction`。
- [ ] `pages/ReaderAloudSettingsPage.ets` 的 13 处 `onUnavailableAction` 调用全部消失，底栏五格全可用。
- [ ] 语速、背景音乐音量、跟随系统三项设置重启后保持。

### 3.4 验收记录

本章尚无任何设备验收记录——这块从零开始。相关登记见 [已知问题](KNOWN-ISSUES.md) 的 KI-A5 / KI-A11 / KI-A12（在线服务纳入范围后已改判「要接，待排期」）。

## 四、阅读记录

### 4.1 能做什么

**这块是六模块里完成度最高的一块**：从记账、三视图浏览、统计概览到合并、扫描修复、清空，整条链路都能在设备上走通。

- **入口**：`我的 → 阅读记录`（`pages/ProfilePage.ets:89`）。列表页是 `pages/ProfileSubPages.ets:3014`-`:3876` 的 `ReadRecordsPage`，宿主挂载在 `pages/Index.ets:7864`。
- **三种视图**：汇总（按日期分组再按书）、时间线（按起始时刻）、最后阅读（每本一条 + 「合并」按钮）。档位循环在 `pages/ProfileSubPages.ets:3078` 的 `cycleDisplayMode()`，标签在 `:3072`-`:3076`，渲染分别在 `:3600`、`:3631`、`:3658`。
- **搜索**：按书名或作者子串过滤（`getVisibleRecords()` `:3082`-`:3087`，输入框 `:3562`-`:3567`）。
- **阅读总成就卡**：显示本书数与总时长，点开进阅读总览页（`:3590`-`:3599`）。
- **热力图**：列表页可开「显示阅读热力图」（`:3847`），日历弹层 `ReadRecordCalendarSheet()` `:3812`-`:3840`，点格子只看当天、再点「查看全部」恢复（`:3820`/`:3822`/`:3836`）。组件本体在 `components/ReadRecordHeatmap.ets`（210 行）。
- **阅读总览页**：`pages/ReadRecordOverviewPage.ets` 519 行，四节——阅读时长柱状图（`:97`）、阅读数据五格（`:165`，`statItems()` `:144`-`:152` = 阅读时间 / 阅读天数 / 累计读过 / 读完书籍 / 在读书籍）、阅读时长榜（`:196`，最多 10 条，整行可点跳书）、读书日历（`:297`）。宿主挂载 `pages/Index.ets:7877`。
- **合并同名记录**：最后阅读视图的「合并」按钮（`:3668`）→ 合并对话框（`:3737`）→ 确认（`:3405`）。
- **扫描与修复**：选项面板的「扫描阅读记录问题」（`:3858` → `runScanIssues()` `:3460`）与「修复阅读记录」（`:3860` → `runRepair()` `:3472`），底层是 `data/ReadRecordRepository.ets:962` 的 `scanIssues` 与 `:1034` 的 `repair`。
- **清空**：`:3861`，带二次确认（`:3785`/`:3786`），提示「阅读记录已清空」（`:3502`）。
- **删除确认两档**：本页不再提醒 / 以后都不再提醒（状态 `:3048`-`:3055`，判定 `:3302`，应用 `:3314`-`:3318`，恢复入口 `:3863`）。
- **未知作者记录归属**：打开书时若书名相同作者不同，问「合并还是保留」（`pages/Index.ets:6104` 的 `checkReadRecordAlias` → `:6140` 的 `askReadRecordAlias`，调用点在 `:6153` 的 `openBook` 开头），决定可持久化、可清除（`:3867`）。
- **书籍详情页内嵌面板**：`pages/BookInfoPage.ets:272` 的动作卡「阅读记录」→ `:151` 的 `openReadRecordPanel()`，面板 `:458`-`:515`，**并且带章号**（`:493`-`:494`）。取数在 `pages/Index.ets:746`-`:774`，`:761` 拼「第 N 章」。
- **记账本身**：`onReadSessionStart/Pulse/Stop` 三回调从阅读页上报（`pages/ReaderPage.ets:847`-`:849`）；不足 10 秒的会话直接丢弃（`minimumReadDurationMs` `data/ReadRecordRepository.ets:93`，判定在 `commit` `:520`）；自动保存间隔 120 秒（`:95`）；连续会话合并间隔 20 分钟（`:97`）；重复会话按「同书 + 同副本 + 相同起止时间」去重（`saveSession` `:561`）。
- **跨午夜切分是真的**：`data/ReadRecordRepository.ets:703` 的 `splitByDate` 按本地时区午夜把一条 23:50–次日 00:20 的会话切成两天（注释 `:698`-`:702`），边界计算 `:718` 的 `boundsOnDate`。

### 4.2 卡在这几处

**一、三视图不显示章号——不是没做格式化，是数据里根本没有这个字段**

`model/ReadRecord.ets:72`-`:80` 的 `ReadTimeRecord` 只有 `id`/`bookId`/`bookName`/`bookAuthor`/`startTime`/`endTime`/`durationMs`，没有 `chapterIndex`；`data/ReadRecordRepository.ets:272`-`:286` 的 `toTimelineRecords(sessions)` 也不带章号。所以 `:3600`/`:3631`/`:3658` 三个渲染分支无从显示。

书签卡里的「第 N 章」（`pages/ProfileSubPages.ets:2996`-`:2997`，属 `struct BookmarkEntryCard` `:2979`）是另一处，不属于本模块。

**二、两处重建会话时把章号写死成 0**

| 位置 | 用途 | 后果 |
| --- | --- | --- |
| `pages/ProfileSubPages.ets:3156`-`:3159` | `getRecordsForDate()` 重建 `ReadRecordSession` 供 `mergeContinuousSessions` 用 | 合并只按时间连续性判断，不看章号，目前无可见错误 |
| `pages/ProfileSubPages.ets:3343`-`:3345` | 单条删除时重建会话供 `deleteSessionById` 用 | 删除按 `bookName` + `bookAuthor` + 起止时间匹配（`:3339`-`:3341`），同样不依赖章号 |

这两处是「将来要显示章号时必须先修」的前置条件，不是当下的可见缺陷。

**三、私密书籍的阅读记录没有脱敏**

上游会把私密分组里书的书名与作者在阅读记录列表里打码：`ui/widget/components/privacy/PrivateListMasking.kt:61` 的 `PrivateRecordKey(name, author)`、`:69` 的 `rememberPrivateLockedRecords`（`:87` 判「打开书要验证」，`:90`-`:93` 按 `isPrivate && !access.isTargetGranted(...)` 判定），消费点在 `ReadRecordScreen.kt:1172`-`:1173`、`:1292`-`:1293`、`:1431`-`:1432` 与 `ReadRecordOverviewScreen.kt:350`-`:352`。

本地 `pages/ProfileSubPages.ets` 的 3000–3900 区间里 `Private|isPrivate|脱敏|模糊封面` 零命中；全仓 `isPrivate` 30 处全是 `BookGroup` 的分组私有标记（`model/BookGroup.ets:9`/`:23`，另 `pages/BookshelfPage.ets:416` 有一句「私有标记未生效」文案）。→ **私密书在阅读记录里照样显示书名**。

### 4.3 算做完的判据

- [ ] 读一本书十分钟，回列表页能在今天这一栏看到它，时长与刚读的时长大致相符（误差几秒内）。
- [ ] 三种视图各切一次，同一批记录在三种视图下都出现，切回来还是最后一次选的那种（重启 App 后仍是）。
- [ ] 搜索结果与输入的书名/作者子串一致，清空输入后列表恢复。
- [ ] 打开阅读总览页，五个统计格（阅读时间 / 阅读天数 / 累计读过 / 读完书籍 / 在读书籍）都有数，柱状图有柱，时长榜有条目。
- [ ] 热力图有格子发色；点某一天的格子，列表只剩那天的记录；点「查看全部」恢复。
- [ ] 造两条同名书的记录，用「合并」合成一条，合并后总时长不变。
- [ ] 手动改坏一条记录后跑「扫描阅读记录问题」能报出问题，「修复阅读记录」能修掉，再扫一次为 0。
- [ ] 清空后列表为空、总览页归零，且再读一本书能重新记上。
- [ ] 书籍详情页点「阅读记录」，面板列出该书的时段与累计时长；最近一次读过的那条带「第 N 章」。
- [ ] 跨零点读一段（23:50–00:20），两天各记一段，而不是全落在一天或全丢。
- [ ] 把一本书放进私密分组，回阅读记录看它的书名——**当前会明文显示**；脱敏做完后应变成打码。

### 4.4 验收记录

本章尚无逐项设备验收记录。相关登记见 [已知问题](KNOWN-ISSUES.md)，另见本文件 2.4 提到的 KI-REL1 与 KI-REL5。

## 五、外观

> 这个模块在应用里叫**外观**，不叫「主题」——`我的 → 设置 → 外观`（`pages/ProfileSubPages.ets:4155`），页面标题也是「外观」（`pages/ThemeSettingsPage.ets:446`/`:450`），与上游中文资源 `theme_setting = 外观` 一致。「主题」在外观页里只是子概念：主题模式、主题风格、主题管理、主题包、自定义配色。

### 5.1 能做什么

**外观页 46 个可见条目里 42 条真接线**，日夜模式、14 套调色板、字体、背景图、护眼、模糊、顶栏底栏 13 项、容器背景全部落盘并生效。

- **主题模式三选一**：跟随系统 / 浅色 / 深色（`pages/ThemeSettingsPage.ets:495`/`:497`/`:499`），回调 `onThemeModeChange('0'/'1'/'2')`，由 `pages/Index.ets` 落盘并换肤。
- **14 套调色板**：横向滚动（`:505`-`:521`，`THEME_PALETTES`，每项 64vp；上游是 `LazyRow` 间距 16dp）。
- **纯黑深色模式**：`:526` 的 Toggle。
- **字体设置**：`:537` 选择字体文件（支持 .ttf/.otf/.ttc）、`:539` 恢复系统字体；导入实现在 `pages/ReaderSettingsPage.ets:2005` 的 `importReaderFontFile` 与 `:2019` 的 `importReaderFontFolder`。
- **字体大小**：`:561` 的 Slider（8–16，显示为 0.8x–1.6x）。
- **自定义颜色**：`:545`，**只在选到第 13 套调色板（`paletteIndex === 12`）时出现**，与上游 `ThemeConfigScreen.kt:266-270` 一致；页面是 `pages/CustomThemePage.ets`（356 行，标题「自定义颜色」`:244`）。
- **主题管理（主题包）**：`:565` 入口 → `pages/ThemeManagePage.ets`（441 行，标题「主题包」`:354`）。五个入口全可用：保存当前设置（`:361`）、导出当前主题（`:363`）、导入主题包（`:365`）、导入旧版主题配置（`:367`）、迁移旧版主题（`:370`，仅在有旧版主题时出现）。已存主题带搜索（`:381`）与列表（`:390`）。
- **背景图片**：`:567` 可展开组（`:569` 日间图、`:571` 日间模糊 0–40、`:574` 夜间图、`:576` 夜间模糊、`:579` 移除背景图片）。
- **首页与导航**：`:585` 可展开组——首页/发现/订阅三枚显隐（`:589`/`:591`/`:593`，书架与我的恒可见）、默认主页面（`:596`）、导航标签显示（`:604`）、主导航顺序（`:613`-`:620`，本地用「上移/下移」两枚按钮承接上游的可拖列表）。
- **显示状态栏**：`:625`。**启用滑动时动画**：`:627`（上游这个键没有任何渲染消费者，本地照实只落盘——与上游现状等价）。
- **顶栏与底栏**：`:629` 可展开组，13 项——折叠应用栏（`:632`）、顶栏按钮样式（`:634`）、合并顶栏按钮（`:643`，仅非 plain 时出现）、显示导航栏（`:647`）、悬浮底栏（`:649`）、液态玻璃（`:652`，仅悬浮底栏开时）、底栏模糊强度（`:655`）、顶栏/底栏模糊半径（`:666`/`:675`，仅控件模糊开时）。
- **书籍详情页三行**：颜色跟随封面取色（`:731`）、网络封面背景（`:733`）、默认封面背景（`:735`）。
- **护眼模式**：`:740` 启用、`:742` 深色时自动开启、`:745`-`:752` 色温滑杆 0–100、`:754` 定时开启、`:757`/`:759` 起止时间。判定逻辑逐句移植上游（`data/EyeProtection.ets:94`-`:105` 的 `isActiveAt`），覆盖层挂在 `pages/Index.ets:6784`-`:6792` 的根 Stack 上。
- **模糊效果**：`:767` 启用控件模糊、`:770` 启用渐变模糊（仅父开关开时出现）。
- **容器设置**：`:777` 容器背景图总开关、`:780` 大容器背景图片、`:783` 项目背景图片、`:787` 容器背景不透明度。

### 5.2 卡在这几处

**一、四处占位，其中两处是「上游也没有」或「平台做不到」**

| 位置 | 标题 | 点下去 | 判断 |
| --- | --- | --- | --- |
| `pages/ThemeSettingsPage.ets:548` | 主题风格（detail「Material Design」） | 「主题风格切换尚未接入」 | 上游 `composeEngine` 是 Compose 引擎切换，ArkUI 只有一套控件体系，**没有可切换的等价分支**；`docs/parity/ZIP-THEME.md:72` 记为「不接」 |
| `pages/ThemeSettingsPage.ets:550` | 切换图标 | 「启动图标设置尚未迁移」 | 上游靠 `AndroidManifest` 预置多个 `activity-alias` 再 `setComponentEnabledSetting` 切换；HarmonyOS 的 `module.json5` 只允许一个 abilities 图标，SDK 无运行时改图标接口 → `docs/parity/ZIP-THEME.md:73` 记为**不适用** |
| `pages/ThemeSettingsPage.ets:724` | 导航布局 | 「导航布局设置尚未迁移」 | **上游没有这个条目**（`docs/parity/ZIP-THEME.md:84` 备注），本地多出来的一行 |
| `pages/ThemeSettingsPage.ets:726` | 多窗布局 | 「多窗布局设置尚未迁移」 | 上游 `multi_pane_layout` 属**额外设备形态**，`docs/PROJECT.md` 列为范围之外 → `ZIP-THEME.md:84` 记为「不接」 |

**二、上游还有两条本地连条目都没有**

- 平板界面（上游 `ThemeConfigScreen.kt:378`，`ZIP-THEME.md:83`）：本地无此条目，属额外设备形态，判「不接」。
- 作者搜索回退（上游 `:425`，`ZIP-THEME.md:88`）：依赖书源的 `ruleBookInfo.relatedBooks`，本地没有在线书源实体，补了也没有消费者，判「不接」。

**三、看着能用、其实只是落盘的三处**

- **启用滑动时动画**（`:627`）：上游这个键自己也没有渲染消费者（`ZIP-THEME.md:81` 原文「全仓 grep 除配置层与设置页外零命中」），本地不造上游没有的动画。
- **启用渐变模糊**（`:770`）：ArkUI 的 `backdropBlur` 不支持渐变梯度，只落盘并参与摘要文案，不产生可见渐变（`ZIP-THEME.md:96`）。
- **预见性返回手势**（`:552`）：能落盘、重启保持，但 SDK 里没有预测性返回 API，没有预览动画（`ZIP-THEME.md:74`）。

**四、浅色模式的配色仍差**

深色适配明显好于浅色，根因是 r300–r317 只改夜间配色与主题包，`entry/src/main/resources/base/element/color.json` 的 `theme_*` 日间色没对齐上游浅色方案。登记为 [已知问题](KNOWN-ISSUES.md) 的 KI-REL5，**未修**。

### 5.3 算做完的判据

- [ ] 外观页六个小节（主题模式 / 主界面 / 书籍详情页 / 护眼模式 / 模糊效果 / 容器设置）都能展开，条目数与上游 `ThemeConfigScreen.kt` 对应小节一致。
- [ ] 深色/浅色/跟随系统各切一次，全 App 立即换肤且重启后保持。
- [ ] 14 套调色板逐个点一遍，每套都换色且重启后保持。
- [ ] 选到第 13 套调色板时「自定义颜色」行出现，点进去能改日夜各 6 个色位并生效。
- [ ] 换一张日间背景图 + 调模糊，退出重进仍是同一张、同一模糊值；「移除背景图片」能同时清掉日夜两张。
- [ ] 关掉「首页」显隐后底栏首页消失、默认主页面下拉里也不再出现首页。
- [ ] 开「控件模糊」后顶栏/底栏真的糊了，再开「悬浮底栏 → 液态玻璃」底栏出现高光。
- [ ] 护眼模式：只开「深色时自动开启」→ 浅色下不生效、切深色自动泛暖；定时开启设成跨零点区间（如 22:00–07:00）能正确判断。
- [ ] 主题包：保存当前设置 → 列表出现一条 → 导出为包 → 删除 → 再导入 → 应用，全 App 配色回到导出时的样子。
- [ ] 剩下四处占位（`:548`/`:550`/`:724`/`:726`）点下去仍是提示——**这是当前正确表现**，不是缺陷；改动它们要先改 `docs/parity/ZIP-THEME.md` 的判据。

### 5.4 验收记录

本章尚无逐项设备验收记录。外观是六模块里验证记录最多的一块，逐条实测写在 `docs/parity/ZIP-THEME.md` 的备注列（多为 r301–r316 的设备结论）；未修的一条是 KI-REL5。

## 六、备份与恢复

### 6.1 能做什么

**Android ZIP 的 28 个数据类别已经全部双向通**（26 类读✓写✓、2 类判不适用），本地 ZIP 导出、导入预览、忽略项、WebDAV 上传下载都能在设备上走通。

- **本地备份**：`备份` 行（`pages/AppBackupSettingsPage.ets:143`）→ 三种（备份到本地 `:256` / 备份到 WebDAV `:258` / 同时备份 `:260`）。导出的是 Android 兼容 ZIP，根目录直接放 JSON/XML 条目与配置，不额外封装。
- **本地恢复**：`恢复` 行（`:149`）→ 从本地恢复（`:263`，选择 ZIP 后先预览再导入）或从 WebDAV 恢复（`:265`，未配置时置灰并提示「请先填写账号与密码」，已配置时显示「最近：xxx.zip」）。
- **预览**：选中 ZIP 后弹预览卡（`pages/Index.ets:531` 的 `backupPreview` 状态、`:5453` 与 `:5477` 两处赋值），列出将要恢复的类别与条数，确认后才写入。
- **忽略项**：备份排除项（`:159`）与恢复排除项（`:155`）分别打开两套勾选面板，面板是 `BackupIgnoreList`（`:272`），至少**保证 `bookshelf.json` 与 `config.xml` 不被排除**（`data/BackupRepository.ets:3102` 的 `isIgnored`，`:3103` 对这两个文件直接返回 false）。
- **WebDAV 设置区**（`:81`「WebDAV 设置」）：服务器地址（`:84`，空则显示「默认（坚果云）」）、账号（`:88`，三态文案）、密码（`:93`，显示已设置/未设置）、子目录（`:97`，空显示「（根目录）」）、设备名称（`:101`）、测试同步（`:105`，测试中禁止重复点）、备份同步模式（`:132`，面板在 `:301`-`:310` 三/四选项）。
- **WebDAV 三层结构**：`lib/WebDav.ets`（415 行，PROPFIND/MKCOL/PUT/GET/DELETE 的薄封装：`check` `:179`、`exists` `:196`、`makeAsDir` `:206`、`listFiles` `:218`、`upload` `:235`、`downloadTo` `:249`、`delete` `:264`）、`lib/WebDavConfig.ets`（169 行，设置结构与落盘）、`lib/WebDavSync.ets`（167 行，`test` `:40` 成功后顺手建 root 与 `books/`、`background/`、`bookProgress/` 四个目录；`listBackups` `:80`、`uploadBackup` `:106`、`downloadBackup` `:123`、`latestBackup` `:139`）。
- **同时备份的真实行为**：`:260` 只调 `onCreateBackup()`；上传由宿主补——`pages/Index.ets:5364`-`:5367` 在本地成功且模式为 `both` 且 WebDAV 已配置时调 `WebDavSync.uploadBackup`，`:5369` 的注释写明「上游 `Backup.kt:322` 的 both 分支同样只记日志、不外抛：本地成功不该被 WebDAV 失败判为失败」。
- **恢复结果提示**：恢复完回到底栏状态行，逐类别报「新增/更新/跳过」——`pages/Index.ets:5692`-`:5710` 十处调用，实现在 `:5783` 的 `describeG2RuleRestore`。
- **28 类现状**：已接入 19 / 部分接入 5 / 未接入 2 / 不适用 2 / 仅归档 0。逐类清单见 [备份与恢复](BACKUP-RESTORE.md)。

### 6.2 卡在这几处

**一、两个真占位**

| 位置 | 标题 | 现状 |
| --- | --- | --- |
| `pages/AppBackupSettingsPage.ets:164` | 导入旧版数据（detail「从旧版本文件迁移」） | 弹「旧版数据导入尚未迁移」 |
| `pages/AppBackupSettingsPage.ets:300` | 选择系统目录（`:299` 的 detail 也写「本地备份目录选择尚未迁移」） | 弹「备份目录选择尚未迁移」；备份固定落在应用自己的目录 |

**二、四个「看着能用、其实只是存了值」的开关**

这四个开关滑动时真的改 `webDavSettings` 并落盘，但没有任何代码执行它们的语义：

| 位置 | 标题 | detail 原文 |
| --- | --- | --- |
| `pages/AppBackupSettingsPage.ets:109` | 同步书籍进度 | 仅保存设置值，阅读进度同步尚未接入 |
| `:117` | 增强进度同步（仅「同步书籍进度」开时出现，`:116`-`:123`） | 仅保存设置值，增强进度同步尚未接入 |
| `:125` | 自动检查新备份 | 仅保存设置值，后台定时检查尚未接入 |
| `:166` | 只保留最新备份 | 仅保存设置值，自动清理备份尚未接入 |

**注意**：`lib/WebDavConfig.ets:30`-`:43` 的 `defaultWebDavSettings()` 里，这四个开关加 `backupSyncMode` **默认分别是 `true` / `false` / `true` / `true` / `'both'`**——也就是说用户第一次配好 WebDAV 时，界面上已经显示「同步书籍进度：开」「自动检查新备份：开」「只保留最新备份：开」，但三件事一件都没发生。

`WebDavSync.ets:59`-`:61` 建了 `bookProgress/` 目录，但全仓没有任何上传/下载阅读进度的消费方——`buildBookProgressUrl` / `buildExportsUrl` / `buildBackgroundUrl` 三个函数只被用来建目录。

**三、首页的 WebDAV 卡还是死的**

`pages/HomePage.ets:236`-`:256` 的「WebDAV 备份」卡有三个按钮，全部走 `onUnavailableAction`：`:245`（备份）、`:250`（恢复）、`:255`（设置），文案都还是「尚未迁移」——**WebDAV 早在 2026-11-11 已落地，这三句是过时文案**。

根因不在文案：`HomePage` 的回调声明（`pages/HomePage.ets:10`-`:17`）里没有 WebDAV 相关回调，宿主 `pages/Index.ets:7039`-`:7040` 也只传了 `onOpenBackup` 与 `onUnavailableAction`。修法是给 `HomePage` 加三个回调并在宿主接线，不是改字符串。

**四、备份页的兼容说明还是旧口径**

`pages/AppBackupSettingsPage.ets:229` 原文写着「尚未迁移的书源、规则、RSS、历史等条目只原样保留，不能在 HarmonyOS 中使用」——书源、RSS 源、RSS 收藏、规则订阅、服务器配置都已接通，这句现在是错的，会误导用户以为导进来的书源用不了。

**五、WebDAV 联网自测与设备侧真包往返都没做过**

[备份与恢复](BACKUP-RESTORE.md) 与[兼容总账](parity/STATUS.md) 在 `server` 一类上如实标注「设备侧真包往返未做，仅主机等价复现」。真机上传下载需要真实坚果云账号，属未验证范围。

### 6.3 算做完的判据

- [ ] 备份到本地 → 用系统文件管理器能看到那个 ZIP，解开后根目录是 `bookshelf.json`、`config.xml` 等条目，不是套了一层目录。
- [ ] 换一台空设备（或清数据后）导入同一份 ZIP，书架、分组、阅读设置、书签、阅读记录、替换规则都回来了。
- [ ] 导入时先看到预览卡（列出类别与条数），取消则一个字都不写。
- [ ] 在「备份排除项」里勾掉一个类别（例如书签），再备份 → 该条目不出现在 ZIP 里；恢复排除项同理。
- [ ] 填好坚果云账号密码点「测试同步」，提示成功且远端出现 `legado/` 与 `books/` 目录。
- [ ] 备份到 WebDAV → 远端出现 `backupYYYY-MM-DD.zip`；改点本地数据后再「从 WebDAV 恢复」，远端列表里能看到这个文件并成功覆盖。
- [ ] 「同时备份到本地和 WebDAV」：拔网线后再点，本地那份仍然生成并提示成功，WebDAV 那条只报失败不影响本地结论。
- [ ] 四个半占位开关（`:109`/`:117`/`:125`/`:166`）**当前只是存值**；其中「只保留最新备份」做完后应能验证：连做三次备份，远端只剩最新一个。
- [ ] 首页 WebDAV 卡的三个按钮点下去直接进备份页对应动作，不再弹「尚未迁移」。
- [ ] 备份页 `:229` 的兼容说明与实际能力一致（不再声称书源/RSS/规则不能用）。

### 6.4 验收记录

本地 ZIP 的类别映射与真包往返记录写在 [备份与恢复](BACKUP-RESTORE.md) 与[兼容总账](parity/STATUS.md)；WebDAV 的联网链路尚无设备记录。相关登记见 [已知问题](KNOWN-ISSUES.md)。

## 维护约定

- 每章固定四节：能做什么 / 卡在这几处 / 算做完的判据 / 验收记录。缺哪节就写「待写」，不要留空标题。
- 「卡在这几处」必须给 `文件:行`，且该行要在当前 HEAD 上真实存在该占位。
- 「算做完的判据」写成可在设备上勾选的步骤，不写「体验流畅」这类无法判定的话。
- 模块状态变了先改本章，再回头同步 [项目队列](PROJECT.md) 的一句话与七表的逐行状态。
