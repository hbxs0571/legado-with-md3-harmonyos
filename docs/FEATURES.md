# 功能交付清单

本文件按**用户视角的功能模块**回答三个问题：这块能做什么、卡在哪几处、做到什么程度算做完。

与七张对照表的分工写死一句：**七表回答「上游有什么、本地接了没有」**（逐行 1226 条，见 [ZIP 兼容总账](parity/STATUS.md)），**本文件回答「用户能用什么」**。两者不重复——本文件不抄逐行状态，只在需要时指到具体 `文件:行`。

## 六模块与优先级

顺序即实施顺序，由使用者确定；与 [项目队列](PROJECT.md) 的编号一一对应。

| 顺序 | 模块 | 现在能不能用 | 主要入口 | 明细 |
| --- | --- | --- | --- | --- |
| 1 | 书架 | 本地六种格式（TXT / EPUB / PDF / MOBI·AZW3 / UMD / 压缩包）的导入闭环可用；在线来源与书单导入导出仍空 | `pages/BookshelfPage.ets`、`pages/BookInfoPage.ets` | 本文第一章 |
| 2 | 阅读器 | 分页与滚动两种模式、目录、书内搜索、主题、替换净化可用；底栏朗读键短按即可起播 | `pages/ReaderPage.ets`、`pages/ReaderSettingsPage.ets` | 本文第二章 |
| 3 | 朗读 | 系统 TTS 与 HTTP TTS 两条合成播放链可用；面板、胶囊、听书界面、后台控制条已接；调速/变声/跨应用悬浮窗受平台限制 | `readaloud/SystemTtsPlayer.ets`、`readaloud/HttpTtsPlayer.ets`、`pages/ReadAloudPlayerPage.ets` | 本文第三章 |
| 4 | 阅读记录 | 概览、热力图、合并、扫描修复、清空都可用 | `pages/ProfileSubPages.ets:3014`-`:3873`、`pages/ReadRecordOverviewPage.ets` | 本文第四章 |
| 5 | 外观 | 主题包、日夜模式、自定义配色可用；启动图标有受限等价物待接（`ZIP-THEME.md:73` 记 `未接`），主题风格与多窗布局上游有而本地无界面条目（`ZIP-THEME.md:72`/`:84` 均记 `未接`） | `pages/ThemeSettingsPage.ets`、`pages/ThemeManagePage.ets` | 本文第五章 |
| 6 | 备份与恢复 | 28 类全部双向通，含 WebDAV 上传下载；旧版数据导入与系统目录选择仍空 | `pages/AppBackupSettingsPage.ets`、`data/BackupRepository.ets`（3773 行） | 本文第六章 |
| 7 | 书源 | 904 条书源可管理、可编辑；多源搜索跨源合并、结果可加入书架在线阅读；发现、换源、登录、调试页可用。已跑通的真实源数与缺口见批次报告 | `pages/ProfileSubPages.ets`、`pages/SearchPage.ets`、`pages/BookSourceEditPage.ets`、`bookSource/` | 本文第七章 |

## 一、书架

### 1.1 能做什么

今天在设备上能走通的完整链路：

- **导入本地书**：系统文件选择器列出六种格式与压缩包七项（`data/BookRepository.ets:534`-`:542` 的 `fileSuffixFilters`：`.txt` / `.epub` / `.pdf` / `.mobi` / `.azw3` / `.umd` / `.zip,.cbz`）。同一本书再导入走「更新目录」分支，不新增第二条记录（`pages/Index.ets` 的 `importLocalBook`，判重键是 `bookUrl`）。
- **书架展示**：分组页签 / 隐藏页签 / 文件夹三种样式（`pages/BookshelfPage.ets:2215`、`:2198`、`:2189`），竖屏与横屏各有列表/网格两档，卡片可显示简介、最新章节、章节角标与阅读进度。
- **分组页签的类型**：上游有 13 个「伴生分组」（全部 / 本地 / 小说 / 漫画 / 音频 / 在读 / 未读 / 已读 / 连载已读 / 完本已读 / 网络未分组 / 本地未分组 / 更新失败），除「全部」外默认隐藏，其余要用户自行打开；本地只补了「本地未分组」一行（`data/BookGroupRepository.ets:495`-`:508`），书架页签为「全部」+ 自定义分组 +「本地未分组」（`pages/BookshelfPage.ets:405`-`:409`），没有在读 / 未读 / 已读这类状态页签。读状态判据本身已在书籍详情页（`pages/BookInfoPage.ets:620`-`:627` 的 `readStateLabel()`），缺的是把它做成页签。详见 [KNOWN-ISSUES](KNOWN-ISSUES.md) 的「智能伴生分组」。
- **排序**：六个排序档加正逆序（`model/BookGroup.ets:39` 的 `BOOK_SORT_OPTIONS`，比较逻辑在 `data/BookshelfSort.ets:11`）；分组自己设了排序档时覆盖书架全局，与上游 `sortBooks()` 取值优先级一致（`BookshelfPage.ets:619`-`:622` 的 `getVisibleBooks()` 先按分组档再回落全局）。
- **分组管理**：新建、改名、显隐、删除、换封面、拖动改分组顺序（回调见 `BookshelfPage.ets:226`-`:240`，面板在 `GroupManagerSheet` `:1391`）。
- **搜索**：书名或作者子串过滤（`BookshelfPage.ets:2175` 的输入框，过滤逻辑在 `getVisibleBooks()` `:608`-`:624`）。
- **更新目录**：菜单项「更新目录」走 `onRefreshToc`（回调声明 `BookshelfPage.ets:225`，菜单项在 `:2107`-`:2115`）。
- **布局设置**：30 余项，含封面宽度上限、列表封面宽度、标题行数/字号/居中/阴影、卡片底色日夜两套、列表分隔线与简介位置、快速滚动条（`LayoutSheetContent` `:1669` 起）。
- **书籍详情**：编辑元数据、查看目录、阅读记录面板、移出书架或删除缺正文记录（动作行 `pages/BookInfoPage.ets:523`-`:535`）。
- **长按**：长按分组卡片进编辑面板，长按书籍卡片进详情（分组卡 `BookGroupCard` 的 `onLongPress`，调用点 `BookshelfPage.ets:2264`；书籍卡 `:2459`）。

### 1.2 卡在这几处

只剩四项仍是**入口在、后端与服务不在**，其余同菜单项已接通（选择模式 `BookshelfPage.ets:2123`、书架管理 `:2124`、导出书单 `:2126`、导入书单 `:2128`、日志 `:2130`，详情页更多操作 `BookInfoPage.ets:614` 是真实菜单）：

| 菜单项 | 位置 | 缺什么 |
| --- | --- | --- |
| 远程书籍 | `BookshelfPage.ets:2092`-`:2093` | 远程书库的 URL 拉取与解析（上游 `ui/book/import/remote/RemoteBookScreen.kt`） |
| 添加网址 | `BookshelfPage.ets:2120`-`:2121` | 同上，从 URL 直接建书 |
| 换源 | `BookInfoPage.ets:529` | 在线书源；文案写的「将在 P5 接入」是历史排期号，现由本文的模块顺序取代 |
| 书籍分享 | `BookInfoPage.ets:610` | 分享面板 |

**在线书源在本地是「只有仓库，没有引擎」**：`model/BookSource.ets` 26 行 7 字段、`data/BookSourceRepository.ets` 186 行纯 CRUD、`data/BookSourceImporter.ets` 117 行导入器，全仓 `http.createHttp` / `JSONPath` / `xpath` / `Jsoup` **零命中** —— 能导入、能列出、能随备份往返，但一条规则都解析不了，一次请求都发不出。

技术可行性已实测（r359，工程外验证工程，主仓零改动）：社区实现 `wip3l/harmony-book-source-engine` 的规则引擎（76 个 `.ts`，25,999 行）与 QuickJS 运行时（MIT，自带 arm64-v8a 与 x86_64 两套预编译静态库）能在本机基线下编译、在模拟器上加载并真的执行 JS；CSS 选择器、属性取值、列表、JSONPath、`@js:` 脚本规则**七项全返回正确结果**；再用一条真实书源（463 条合集里的「得奇小说」）跑通了**搜索 → 目录 1302 章 → 正文**的完整链路。它只提供引擎，搜索 / 发现 / 正文的调度层不在这个包里（作者指向自己的阅读器项目，那部分约 8,000 行），宿主适配（ArkWeb、Cookie、TLS、模型映射）一件没接。完整实测数据、两种接入方式的成败差别与尚未验证的项见 [已知问题](KNOWN-ISSUES.md)「书源引擎：能接、已上机验证、但还差调度层」。

另有**两处「看着能用、其实不生效」**，比纯占位更容易被误判：

- **手动排序档只在手动档下能拖**：`Book_SORT_OPTIONS` 的第 4 档「手动排序」按 `book.order` 比较（`data/BookshelfSort.ets:45`-`:47`），拖拽入口是书卡 Grid 的 `onMove`（`BookshelfPage.ets:2481`-`:2484`）加 `editMode`（`:2493`，判据 `canReorderBooks()` `:724`-`:729` 只在排序值 3 时放开）；拖完落库 `data/BookRepository.ets:1450` 的 `saveBookOrder`（接线 `pages/Index.ets:7071`）。非手动排序下拖拽被关掉，屏幕不会变化，这是上游行为。
- **下拉刷新只是存字段**：分组编辑里的「下拉刷新」开关写的是 Android 兼容字段 `enableRefresh`（读 `BookshelfPage.ets:997`、写 `:1033`），界面自己标了「仅保存 Android 兼容字段；当前不控制实际更新」（文案在 `:1291`-`:1292`）。
- **缺正文的记录**：书目存在但正文文件丢失时卡片走详情页而非阅读页（`BookshelfPage.ets:2444`-`:2448` 的 `isBodyMissing` 分支），详情页给的是「移出缺正文记录」而不是「补正文」。

### 1.3 算做完的判据

第 1 章收口的标准是下面每一项都能在设备上一次走通，且中途不出现「尚未迁移」提示：

- [ ] 导入一本 TXT 与一本 EPUB，书架出现两条卡片，封面、书名、作者、章节数正确。
- [ ] 同一本再导入一次，提示已更新，书架仍是一条。
- [ ] 三种分组样式各切一遍，页签/文件夹/隐藏三态都能回到书架且筛选不丢。
- [ ] 新建分组、改名、换封面、拖到另一个位置、删除，五步都生效且重启后保持。
- [ ] 六个排序档各选一次，顺序与预期一致；切到「手动排序」后**能拖动改序并持久化**。
- [ ] 搜索框输入书名片段与作者片段，均能过滤；清空后恢复全量。
- [ ] 布局设置里改封面宽度、标题居中、卡片底色，书架立即变化，重启后保持。
- [ ] 「更新目录」对已导入的书可用，章节数与最新章节变化。
- [ ] 长按书籍进详情，元数据编辑保存后书架卡片同步刷新。
- [ ] 菜单里七项入口五项已接通（选择模式、书架管理、导出书单、导入书单、日志），剩下远程书籍与添加网址两项要么接通，要么保持明确的未迁移提示（不能静默失败）。

### 1.4 验收记录

本章尚无逐项设备验收记录。设备截图与命令行输出按 [验证记录](VALIDATION.md) 的格式补记，不要写在本节。

## 二、阅读器

### 2.1 能做什么

- **两种阅读形态**：分页与滚动。翻页动画六档在 `reader/ReaderCanvasSurface.ets:31` 的 `ReaderTransitionMode` 里齐全（覆盖/滑动/仿真/滚动/淡入淡出/无动画），顺序与上游 `GlobalThemePage.kt:353-360` 一致。
- **排版**：字号 5–50 逐级可调、行距/段距/首行缩进/左右边距、六种对齐、正文与标题可分别设字体（`reader/ReaderTextLayoutEngine.ets:48` 的 `ReaderTextLayoutStyle`）。字体文件可以导入并注册（`ReaderFontRepository.importFont`，`pages/ReaderSettingsPage.ets:2005`），也支持导入整个目录批量注册（`:2019`）。
- **目录**：四个页签——信息 / 目录 / 书签 / 笔记（`pages/CatalogPage.ets:270` 的 `getTabLabel`），章节树支持卷与层级（`reverseTocHierarchy` `:207`），当前章自动滚到可见（`hasAutoScrolledCurrentChapter` `:97`）。
- **书内搜索**：全文或正则两种模式，支持替换模式、只搜本书历史（`pages/ReaderSearchPage.ets:50`-`:57` 的七个状态位），结果上限 200 条，遍历章节带进度显示（`:213` 的 `BookRepository.forEachChapter`）。
- **书签与笔记**：下滑添加/取消书签（`swipeToAddBookmark`）、自定义书签角标图片与大小（`bookmarkBadgeImage`/`bookmarkBadgeSize`）、七种标记效果与 16 色预设（`pages/ReaderMarkingEditor.ets:8`-`:22`），编辑与备注在 `ReaderMarkingEditor`（532 行）。
- **替换净化**：规则在正文进入排版前生效，正则跑在 taskpool worker 里逐条计时，单条超时自动停用该规则并提示（`data/ReplaceRuleEngine.ets:1`-`:17`、应用在 `data/BookRepository.ets:1863`）。规则的存取、分组排序、导入导出与执行编排全部装在 `data/ReplaceRuleRepository.ets`（1,217 行，本地无 DAO 层的必然结果），执行部分约占 210 行（`:910`-`:1120`）——上游把这部分独立在 `help/book/ContentProcessor.kt`（297 行），本地尚未拆出，可测性受影响的说明见 [`docs/KNOWN-ISSUES.md`](KNOWN-ISSUES.md)「替换规则：Repository 混装五类职责」。该节另记了为什么不用第三方 ORM 补 DAO 层：官方无 ORM 模块，社区三个库都拿不到 Room 的编译期校验。
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

界面叫法是**朗读**（阅读页底栏那一格、`我的 → 设置 → 朗读设置`），技术上就是 TTS。`httpTTS.json`、
`@kit.CoreSpeechKit`、`@kit.MediaKit` 这些词指技术侧。九批实现后的状态按本节实测记录。

### 3.1 能做什么

**两条合成播放链都能把一段正文走完**（模拟器无扬声器，验收口径是「合成链路走到 onComplete」，不写「验证出声」）：

- **系统 TTS**（`readaloud/SystemTtsPlayer.ets`）：单例持有引擎，`speak` 后等 `onComplete` 才推进下一段；
  段间高亮与翻页跟随（`onSpanChange` → `ReaderPage` 按 `SpeechUnit.start/end` 上底色并回写阅读进度）；
  实测连续多段 `speak start → onComplete → unit advance` 串行链成立，停止后 60 秒内复用引擎、不二次 `createEngine`。
- **HTTP TTS**（`readaloud/HttpTtsPlayer.ets`）：选中 HTTP 源后把每段合成音频下载到 `cacheDir`，用 `AVPlayer(fdSrc)` 播放，
  `completed` 才推进；本地测试服务器实测 `?text={URL编码正文}&speed=&tone=` 一段接一段到达。
  这里 `ttsSpeechRate` 通过 `setSpeed` 真正调速（1..10 映射 AVPlayer 10 档），是「系统不支持调速」那句话的落点。
- **切段与偏好**：`readaloud/SpeechSegmenter.ets` 四档切段（默认/段落/按页/标点）；14 个偏好键存
  `data/ReadAloudSettingsRepository.ets`，逐字对齐上游键名，杀进程重开仍在。

**界面与形态**（`pages/`）：

- **朗读面板**（`ReaderAloudSettingsPage.ets`）：上一句/暂停/停止/下一句、上一章/下一章、定时三档、
  语速滑杆（下方注明只对 HTTP 源生效）、底栏五格；设置浮层 `ReadAloudConfigPanel.ets` 接上游
  默认界面/背景下拉、胶囊显隐与自动收起、预合成并发、段落间隔、缓存清理时间与缓存大小/清空、胶囊位置复位。
- **朗读胶囊**（`ReaderPage.ets` 顶层浮层）：封面圆图 + 播放暂停 + 进度环内含停止，3 秒自动收起、
  可拖并钳位吸附、位置复位；展开态点封面打开听书界面。
- **听书界面**（`ReadAloudPlayerPage.ets`）：目录/封面/正文三页、当前句与下一句、进度条 seek、
  Transport 与设置按钮，接同一个播放器单例。
- **后台**（`readaloud/ReadAloudBackgroundTask.ets`）：`AUDIO_PLAYBACK` 长时任务 + AVSession，
  控制条 play/pause/上下段/停止接到播放器；`module.json5` 加 `KEEP_BACKGROUND_RUNNING` 与 `audioPlayback`。
- **引擎与音色管理页**（`ReadAloudEnginePage.ets`）：HTTP 源的新增/编辑/删除/设为当前、音色目录拉取与排除。

### 3.2 卡在这几处（平台做不到，如实标注）

- **系统 TTS 无调速**：`TextToSpeechEngine` 只有 `setListener/speak/listVoices/stop/isBusy/shutdown`，无 `setSpeechRate/setPitch/setVolume`。
  语速滑杆保留并写 `ttsSpeechRate`，但系统朗读不变速；只有 HTTP 源真生效。
- **胶囊是应用内浮层**：`SYSTEM_FLOAT_WINDOW` 是 `system_basic` 权限（SDK `PermissionDefinitions.json:615`），
  三方拿不到；退出阅读器胶囊即消失。
- **变声器不可实现**：平台无面向播放的音频效果 API（`@ohos.multimedia.audio.d.ts` 只有 loopback 的混响/均衡预设，
  无 Equalizer 等播放侧音频效果）；入口保留，点开如实说明，不做空页面。
- **音色只有 3 条**：系统 TTS 实测 zh 聆小珊(13)/zh 凌飞哲(21)/en(8)；`online=0` 在线不支持。
- **后台续播限制**：长时任务与 AVSession 激活有日志证实，但模拟器上系统 TTS 引擎在应用失焦后回调冻结，
  未测到持续推进；媒体控制条在模拟器通知栏未显示（系统侧发出通知后被 SystemUI 移除）。
- **HTTP 源仅纯 URL**：AnalyzeUrl 模板/JS、`loginCheckJs`、`jsLib` 依赖 JS 引擎，鸿蒙无对应物，字段保留不执行。
- **云端 TTS 整层未建（不是平台限制）**：上游朗读有三条引擎路径，本地只落了两条（系统 TTS、自建 HTTP 源）。
  上游第三层是七家云端 provider（OpenAI / Gemini / MiMo / Azure / 阿里云 / AWS Polly / 火山）加一张 `cloud_tts_engines` 配置表，
  代码 682 行 + 界面 2,885 行；上游把云端引擎合成成一个假 `HttpTTS` 源塞进同一条 HTTP 播放服务，**没有第三条通道**。
  本地 `RdbSchema.ets` 27 张表无 `cloud_tts_engines`，`mimo`/`cloudTts` 在 `.ets` 里零命中，引擎类型只有 `'http'` 一个值——
  `ReadAloudEnginePage.ets` 的「引擎」tab 是借壳的，列的是 `httpTTS` 源。
  平台侧并不拦：`rcp` 的 `IncomingDataCallback`（`@hms.collaboration.rcp.d.ts:292`）、`AudioRenderer.write`（`@ohos.multimedia.audio.d.ts:6105`）、
  `setSpeed`（`:6344`）基线 20 全部覆盖。详见 [KNOWN-ISSUES](KNOWN-ISSUES.md) 的「云端 TTS 整层未建（r357 盘点）」。
- **朗读只能是整包，不能边合成边播**：本地 `readaloud/HttpTtsPlayer.ets` 走 `downloadToFile` + `AVPlayer(fdSrc)`，
  音频一个字节都没穿过应用内存，首音延迟 = 整段合成时长。平台侧并不缺推流能力——`AudioRenderer.on('writeData')`
  （`@ohos.multimedia.audio.d.ts:6871`）每 100ms 要 4800 字节，`setSpeed`（`:6344`）走 Sonic、0.5x 以上不变调——
  缺的是把合成内核放进应用进程。另有一条**平台事实**要记住：鸿蒙没有「系统 TTS 引擎插槽」（五条证据链见 KNOWN-ISSUES），
  所以「做成独立应用、让别的应用调用」这条路不成立。详见 [KNOWN-ISSUES](KNOWN-ISSUES.md) 的「朗读的平台底座（r358 盘点）」。

- **听书播放页没有几何 morph**：上游是 Activity 级共享元素浮层（`ReadAloudMorphState` 单一进度驱动面板、封面、透明度与圆角），本地是根 `Stack` 条件渲染，打开只有整层出现。封面飞行可以做（`geometryTransition`），面板从胶囊矩形长成整窗只能近似（ArkUI 布局动画会让内容跳变或拉伸），返回手势跟手做不到（无 predictive back）。详见 [KNOWN-ISSUES](KNOWN-ISSUES.md) 的「听书播放页的 morph 浮层（r367 盘点）」。

### 3.3 算做完的判据（按实测）

- [x] 底栏朗读键短按起播，逐段合成链走到 `onComplete`，段间高亮跟随并回写阅读进度。
- [x] 面板 Transport、上下章、定时、九项设置均真接线；暂停后无新 `speak start`，图标切播放。
- [x] 听书界面三页与当前句/下一句、seek、目录选章接同一播放器。
- [x] HTTP 源保存重开仍在；音色目录可拉取落库；导出 `httpTTS.json` 不含三个本地扩展列。
- [x] 缓存 key 含源/语速/正文三要素；并发限流 coerceIn(1,8)；预合成命中（cache=false → cache=true）。
- [ ] 真机扬声器出声、后台持续续播、通知栏媒体控制条——模拟器无法验证，见 3.4。
- [ ] 云端 provider 七家与 `cloud_tts_engines` 表——整层未建，见 3.2 末条。
- [ ] 边合成边播（推流）——未做，见 3.2 末两条。

### 3.4 验收环境说明

以上链路在模拟器（127.0.0.1:5555）用 hilog + dumpLayout 验证，模拟器无扬声器，
故只记录「合成链路走到 onComplete/onStart」，不出「已验证出声」的结论。平台做不到的项逐条见
[已知问题](KNOWN-ISSUES.md) 与批次报告。

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

**一、一处占位：切换图标**

| 位置 | 标题 | 点下去 | 判断 |
| --- | --- | --- | --- |
| `pages/ThemeSettingsPage.ets:583` | 切换图标 | 「启动图标设置尚未迁移」 | SDK 有受限等价物：`@hms.core.appgalleryservice.appInfoManager.d.ts` 的 `:65 queryDynamicIcons` / `:80 selectDynamicIcon` / `:91 disableDynamicIcon`（均 @since 5.0.3(15)，入口 `@kit.AppGalleryKit`）；图标须先在 AppGallery Connect「分发 > 服务 > 图标管理」上传并审核，应用只能从已审集合里挑，服务需邮件申请（beta）→ `docs/parity/ZIP-THEME.md:73` 记 `未接`，不是 `不适用` |

多窗布局（上游 `multi_pane_layout`）与主题风格（上游 `compose_engine`）本地均无界面条目，`docs/parity/ZIP-THEME.md:84`/`:72` 记 `未接`。

**二、上游还有两条本地连条目都没有**

- 平板界面（上游 `ThemeConfigScreen.kt:378`，`ZIP-THEME.md:83`）：本地无此条目，属额外设备形态，判「不接」。
- 作者搜索回退（上游 `:425`，`ZIP-THEME.md:88`）：依赖书源的 `ruleBookInfo.relatedBooks`，本地没有在线书源实体，补了也没有消费者，判「不接」。

**三、看着能用、其实只是落盘的三处**

- **启用滑动时动画**（`:627`）：上游这个键自己也没有渲染消费者（`ZIP-THEME.md:81` 原文「全仓 grep 除配置层与设置页外零命中」），本地不造上游没有的动画。
- **启用渐变模糊**（`:770`）：ArkUI 的 `backdropBlur` 不支持渐变梯度，只落盘并参与摘要文案，不产生可见渐变（`ZIP-THEME.md:96`）。
- **预见性返回手势**（`:552`）：能落盘、重启保持，但 SDK 里没有预测性返回 API，没有预览动画（`ZIP-THEME.md:74`）。

**四、浅色模式的配色仍差**

深色适配明显好于浅色，根因是 r300–r317 只改夜间配色与主题包，`entry/src/main/resources/base/element/color.json` 的 `theme_*` 日间色没对齐上游浅色方案。登记为 [已知问题](KNOWN-ISSUES.md) 的 KI-REL5，**未修**。

**五、M3 色位只落了一小半，容器色与错误色一律降级**

上游 `ui/theme/LegadoTheme.kt` 的 `LegadoColorScheme` 有 **53 个色位**，代码里真被引用的有 **34 个**（`colorScheme.xxx` 全仓 1,531 处）。本地 `entry/src/main/ets/data/ThemePalette.ets` 的 `ThemePaletteColors` 只有 **11 个字段**，`publishPaletteColors` 只广播 **9 个** `AppStorage` 键。

缺口 25 个，分三种性质：**18 个值要新增**（`error` 63 次 / `secondaryContainer` 62 / `outlineVariant` 53 / `primaryContainer` 28 / `onSecondaryContainer` 26 / `onPrimaryContainer` 20 / `surfaceVariant` 16 / `background` 6 / 其余 10 个小用量）、**2 个值已有只缺广播键**（`secondary` / `tertiary`）、**5 个可由现有色位派生**（`onSheetContent`←`surface` / `cardContainer`←`surfaceContainerLow` / `onCardContainer`←`primary` / `onBackground`←`onSurface` / `surfaceInput`←`bookInfoInputColor`）。

两个最直接的后果：

- **选中态是「亮一点的灰」而不是带主色调的容器色**。全仓 27 处写着「本地没有该色位，用 xxx 顶」的降级点，分布在 11 个文件（`pages/BookInfoPage.ets` 5 / `pages/CatalogPage.ets` 4 / `pages/ThemeSettingsPage.ets` 3 / `pages/ReaderSearchPage.ets` 3 / `pages/ReaderPage.ets` 3 / `pages/ReaderSettingsPage.ets` 2 / `pages/Index.ets` 2 / `components/ThemeSelectors.ets` 2 / 另三处各 1）。深色主题下差异小，浅色与彩色主题下明显偏灰平。
- **危险色是 16 种写死的红，没有统一来源**。本地全仓 `themeColorError` 零命中，`#FFB4AB` 10 处、`#D99AA5` 8 处、`#FF6B6B` 7 处、`#CF3E40` 3 处……换主题时一个都不会跟着变。

代价：**432 个色值**（18 色位 × 日/夜 × 12 套内置配色）＋ `@StorageProp` 样板声明 **150–250 行**（ArkUI 必须在每个 struct 单独声明，没有 Compose `CompositionLocal` 那样的继承）＋ 27 处降级点改造，**合计约 700–900 行**。另有一条独立的大账：真做「动态取色」要移植 Material Color Utilities 的 HCT 算法（约 1,500 行），本地零命中，不做则「动态取色」档永远回落内置默认配色。

**判断：值得做但不排现在**——它不改任何能力，纯观感；本地还挂着私密脱敏、朗读两处死控件、阅读记录三视图等真功能缺口。完整量化、逐色位用量表与四批拆法见 [已知问题](KNOWN-ISSUES.md) 的 KI-THEME2。与上面第四条同源（都是配色没对齐上游），但根因不同：第四条是浅色值没抄，本条是色位根本没建。

**六、形状设置阅读域不读，面板没有公共容器**

颜色之外还有两层，性质不同：

- **形状：令牌齐备，阅读域不跟随。** 上游没有自定义 `Shapes`，形状由 `SplicedColumnGroup`（`ui/widget/components/SplicedColumnGroup.kt:50-54`，三档圆角 0 / `baseCardCornerRadius` / 16dp）加各组件就地写值决定。本地这块做得好：`data/ThemeCardStyle.ets` 字段齐全，`pages/Index.ets:3710-3727` 广播 10 个键，`themeCardRadius` 有 **12 个文件 40 处**消费，设置类页面全部跟随。但**九个阅读域文件对 `themeCardRadius` / `themeCardBorderWidth` / `themeDividerWidth` 全部 0 命中** —— 外观页把卡片圆角从 16 拖到 40，进阅读器一个角都不动。而阅读域自己把「卡片圆角」用了 18/20/22/24/26 五种值，`pages/ReaderSearchPage.ets` 一个文件里就出现五档。
- **面板：没有公共容器。** 上游 30 处面板全走 `AppModalBottomSheet`，高度由内容驱动（`animateContentSize` + `heightIn(max = 容器高 × 0.8f)`）、内边距固定 16、抓手与容器色统一。本地阅读域是 **5 个手写 `Stack({ alignContent: Alignment.Bottom })` 弹层**，全仓 19 处 `bindSheet(` 阅读域一处都没有。后果四条：高度写死百分比（`pages/ReaderSettingsPage.ets:2548-2555` 三档 62%/68%/80%，源码注释自陈「探针实证做不到内容自适应」）、遮罩 9 种值、内边距 7 种值、抓手尺寸对但颜色分两派（`pages/ReaderPage.ets:4758` 与 `:8575` 写死 `'#C5C6CD'`）。

三块性质不同、修法也不同：颜色要补数据（432 个色值），形状要接消费点（不新建抽象），面板要新建组件并迁 5 个弹层。**面板这块要先探针**——ArkUI 上「内容自适应高度 + 上限 80%」是否成立还没测过 `bindSheet` 的 `detents` / `SheetSize.FIT_CONTENT`，不确认就动 5 个弹层等于赌。完整量化与逐文件圆角清单见 [已知问题](KNOWN-ISSUES.md) 的 KI-THEME4。

**七、外观体系还有六块没盘（r355 粗测）**

颜色、菜单取色、形状面板之外，同一套主题体系里还有六块：

- **排版语义阶梯已建成（改造前是缺口）。** 上游 `ui/theme/LegadoTheme.kt:85-119` 有 24 个槽位（headline/title/body/label × 三档 × 普通与 `Emphasized`），引用 **696 处 / 186 文件**。本地原 `fontSize(N)` 字面量 **1,282 处、20 种字号**（旧文档写 1,189 为粗测值）已于改造后全部分批迁入 `components/typography/TypographyTokens.ets` 的 24 槽位常量，**字面量归零**；9 个旧 `FONT_*` 常量已按上游 settingItem 语义统一（settings 组件族 32 处换成槽位常量、15 处补 Emphasized 字重，UiTokens 删全部 9 个定义）。行高 33 处手写值已统一：32 处固定值改成配对字号槽位的行高常量，1 处阅读器 Canvas 动态行高保留——其中 13 处 21/22 上游无对应的偏离值已消除。全仓 173 处 `.fontWeight()` 未批量改写（无上游语义锚点）。后果（改造前同层级字号不一）已消除。
- **图标命名不成体系。** 上游 Material Icons 引用 **1,195 处**（族限定末端名 **225 种**；全末端名口径 241 种；原记录的「263 种」未查到复现口径），另有 **177 个** vector drawable（`res/drawable` 下 225 个 xml：按 `<vector` 子串 177、按严格根标签 173）；本地 `AppGlyph` **84 个**名字 + 140 个 svg，功能不缺，但 20 多个带 `profile` 前缀、其余不带，播放/暂停图标绕过 `AppGlyph` 直接用 `Image($r(...))`。
- **动效有底座没档位。** 上游 `MotionScheme.expressive()` 统一接管，`tween(` 143 处 + `spring(` 15 处；本地 `duration:` **82 处 11 种值**、`curve` 只 3 种，没有常量收口。
- **模糊主界面通了，其余硬编码。** 本地 `backdropBlur` **24 处**，其中 18 处是写死数字（12/16/20/30），只有 `components/TopBar.ets:195` 与 `pages/Index.ets:11262` 读偏好。
- **阴影方向相反。** 上游全仓只有 3 处 `Modifier.shadow`（M3 靠色位分层不靠投影），本地 `.shadow(` **10 处**、7 种参数组合。
- **无障碍差两个数量级。** 上游 `contentDescription`/`semantics` **1,017 处**，本地 `accessibilityText` 类 **14 处**。

这六块只做了关键词计数与取样，**没有逐行取证**（与 KI-THEME2/3/4 的取证深度不同）。其中**排版**最值得先查：它和动效同属「看起来都一样、细节全不同」的典型。完整粗测数据与判断见 [已知问题](KNOWN-ISSUES.md) 的 KI-THEME5。

**八、组件级形变（r356 已上机验证，能力不缺）**

上游有一整类「会变的控件」：下拉刷新指示器（圆 ↔ 八瓣软爆裂）、听书播放键（容器 + 图标 + 颜色三重形变）、底栏标签（逐字滑入）、FAB 菜单（图标 Close ↔ MenuOpen）、加载圈、试听按钮旋转、封面 morph 展开。本地只有下拉刷新（`components/PullRefreshIndicator.ets` 自绘 Canvas）与开关（`components/UiSwitchControl.ets`）两个有等价物，其余全无。

此前判断「ArkUI 没有形状插值 API」是错的。`@AnimatableExtend` + `AnimatableArithmetic<T>`（均 @since 10，基线 20 就能用）可以驱动 `Polygon.points` 做逐帧插值，实测插值速率 **118.6–240 次/秒**、`springMotion` 下 `multiply` 仍被逐帧调用、128 顶点无卡顿、72vp/36vp 小尺寸无毛刺。**缺的是实现，不是平台能力**。四条硬约束：装饰函数必须与 `build()` 同文件、两端采样点数必须一致、`points` 是绝对坐标不随宽高缩放（`Shape`+`viewPort` 包裹会不显示，只能用 `scale`）、`extends Array` 可编译。完整实测数据与十二类控件对照见 [已知问题](KNOWN-ISSUES.md) 的 KI-THEME6。

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

`pages/AppBackupSettingsPage.ets:229` 原文写着「尚未迁移的书源、规则、RSS、历史等条目只原样保留，不能在 HarmonyOS 中使用」——书源、RSS 源、RSS 收藏、规则订阅、服务器配置都已接通，这句现在是错的，会误导用户以为导进来的书源用不了。（r364 补充限定：**RSS 只接通了备份导入导出这一半**——`model/RssSource.ets` 与 `data/RssSourceRepository.ets`/`RssStarRepository.ets` 都在，但没有 RSS 页面、没有 feed 抓取与解析，上游 RSS 是 33 文件 / 6,996 行。所以那句旧文案对 RSS 其实不算全错，只是把「不能使用」说成整体，而实际是「能导入导出、不能抓取阅读」。详见 [`docs/KNOWN-ISSUES.md`](KNOWN-ISSUES.md) 的「缺失的层」第四节。）

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

## 七、书源

本章记在线书源模块的用户可见能力。它不在用户确定的前六项队列里，是 2026-11-20 按 12 批（P0–P11）单独落地的；逐批提交号、P0 准入数据、跑通的书源数与明确缺口见[批次交付报告](booksource/BATCH-REPORT.md)。

脚本执行不是全量：兼容书源脚本走引擎的手写解释器（30 个 `java.*` 白名单）加 QuickJS 表达式兜底、再加 ArkWeb 分阶段；`java.*` 桥对 904 条真实书源覆盖 92.5%，上游 Rhino 式「任意 Java 可达」在鸿蒙没有对应机制。见[已知问题](KNOWN-ISSUES.md)的「书源脚本运行时：白名单子集，完整 JS 引擎在包里但没接（r366 盘点）」。引擎本身能补什么、什么该在我们这层做、推进顺序，见同一篇的「书源引擎能改造到什么程度（r366 补记）」。

### 7.1 能做什么

- **书源管理**：「我的 → 书源管理」列出全部 904 条书源（`pages/ProfileSubPages.ets` 的 `BookSourceManagePage`，用 `LazyForEach`），支持关键词搜索、分组筛选、七种排序（手动 / 权重 / 名称 / URL / 更新时间等）、按域名分组、拖拽重排、长按进多选后的 11 项批量操作（启用/禁用、启用/禁用发现、加/移分组、置顶/置底、选区间、校验、导出）与条目菜单 7 项（置顶/置底/搜索/调试/编辑/删除/启用发现；无 `loginUrl` 的源不显示登录项）。
- **书源编辑**：`pages/BookSourceEditPage.ets` 六 tab 共 68 个字段槽，直接读写整条 Legado 原始 JSON（`sourceJson` 是唯一真值，派生列保存时重建），支持新建书源；溢出菜单含复制/粘贴/分享/搜索/补全/登录/清 Cookie/变量/日志九项。
- **搜索与阅读**：`pages/SearchPage.ets` 对启用的文本源 8 并发搜索，按书名/作者四桶归并、同书跨源合并来源数、边搜边出、可随时取消；点结果加入书架后 `Index.openBook` 走在线分支，`bookSource/OnlineBookService.ets` 缓存优先、网络兜底取目录与正文，复用引擎规则解析与后处理，打开即能读。
- **发现与换源**：`pages/DiscoverPage.ets` 按 `exploreUrl` 的四种写法解析源与分类，按源/分类翻页；`pages/ChangeSourceSheet.ets` 单本换源，候选源搜索后展示目录章节数，按 Jaccard 章节名相似度迁移阅读进度（对应上游 `BookHelp.getDurChapter`），失败保留原书。
- **登录、导入导出、调试**：`pages/SourceLoginPage.ets` 对有 `loginUrl` 的源按 `loginUi` 解析结果走表单或内嵌 WebView 双模式，loginHeader/loginInfo/cookie 三载体回写并在后续请求自动带上；`pages/ProfileSubPages.ets` 支持本地文件 / 在线 URL 导入与整表导出，均为标准 Legado JSON（扫码因平台无对应 API 弹真实提示，不伪造）；`pages/BookSourceDebugPage.ets` 对搜索/发现/详情/目录/正文五类目标打点，按过程/响应/错误过滤并可点开详情。

### 7.2 卡在这几处

- **只覆盖 A1/A2 类纯 URL 源**：P0-ter 准入实测 A1 60% / A2 60%，A3/A4（规则里 `{{}}` 内代码模板）与 C 层脚本源通过率 0%/4%，属引擎语法与 `java.*` 桥能力边界，不承诺；详见[批次报告](booksource/BATCH-REPORT.md)与[已知问题](KNOWN-ISSUES.md) KI-BS1–BS6。
- **未实现的能力**：书源回调按钮、简介 usehtml/useweb/md 渲染与简介 JS、角色/知识/事件卡（依赖范围外的 AI 服务）、批量下载与批量换源、书架管理页里的书源选择/换源预览面板、`myBookSource.json` 旧版导入、`keyboardAssists` 语法表；在线书进度持久化与目录定时刷新红点留待后续。
- 书源调试页的过程日志是宿主自包装 `WebBookService` 打点产出——引擎的 `BookSourceDebugContext` 是拉取式结构且当前链路未透传，无法直接给出带 message/耗时/类别的日志流。

### 7.3 算做完的判据

- [ ] 「我的 → 书源管理」能看到 904 条书源，搜索「笔趣阁」收敛到含关键词的结果，七种排序切换后首项随排序变，长按进多选能批量启用/禁用并真正落库。
- [ ] 编辑页六 tab 切换正常，改一个字段保存后重进仍在新值；新建一条源后能在管理页找到。
- [ ] 搜索页输入书名，多个源并发返回结果，同一本书只出现一次并显示命中来源数，边搜边出，中途点取消能停止。
- [ ] 搜索结果加入书架后打开，能加载目录并读到正文（真实源实测「剑来」→ 77读书网目录 1362 章、正文 770 字）。
- [ ] 发现页能按源、按分类翻页；换源后书籍保留阅读进度，失败时原书不变。
- [ ] 有 `loginUrl` 的源能弹登录表单或 WebView，保存凭据后搜索请求带上登录态。
- [ ] 调试页选「搜索」、输入关键词开始，能看到带耗时与类别的日志条目，按「错误」过滤后只剩错误条目。

### 7.4 验收记录

P0 三轮准入数据与 P1–P10 逐批提交、上机结果写在[批次交付报告](booksource/BATCH-REPORT.md)与[验证记录](VALIDATION.md)的 r352 段；模拟器跑不出、需真机的项在交付报告的「未验证清单」。

## 维护约定

- 每章固定四节：能做什么 / 卡在这几处 / 算做完的判据 / 验收记录。缺哪节就写「待写」，不要留空标题。
- 「卡在这几处」必须给 `文件:行`，且该行要在当前 HEAD 上真实存在该占位。
- 「算做完的判据」写成可在设备上勾选的步骤，不写「体验流畅」这类无法判定的话。
- 模块状态变了先改本章，再回头同步 [项目队列](PROJECT.md) 的一句话与七表的逐行状态。
- 判据要在真实数据上走通：书取 `<workspace>\测试\Book\` 里现成的，备份取 `测试/backup.zip`。用自己造的小样本勾完不算做完，理由见[代码约定](CODE-CONVENTIONS.md)第七节。
