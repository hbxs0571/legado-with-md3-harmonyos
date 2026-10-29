# 书架 / 书籍元数据 / 进度 对照表

本表按 [模块对照要求](../CODE-CONVENTIONS.md) 第四节点完一次，行粒度是一次用户可感知的操作。
状态四值：`已接` / `未接` / `不适用` / `待定`；`不适用` 写理由，`待定` 写阻塞项。**本表无 `待定` 行。**

- 盘点日期：2026-10-29
- 上游基线：`legado-with-MD3`（Android，Compose）
- 本地实现：`entry/src/main/ets`（HarmonyOS，ArkTS）

## 盘面

| 块 | 条数 | 已接 | 未接 | 不适用 |
| --- | --- | --- | --- | --- |
| A 书架主屏 | 45 | 21 | 24 | 0 |
| B 书籍元数据 | 34 | 21 | 10 | 3 |
| C 阅读进度 | 17 | 16 | 1 | 0 |
| 合计 | 96 | 58 | 35 | 3 |

> 早前口头估计为「三块 67 条」，逐项核完实为 96 条：卡片展示按标签/字数/来源各拆一条，详情页按上游 `BookInfoMenuAction` 的 20 个枚举值逐项展开。其中 `CustomButton`（书源自定义按钮）、`ToggleSplitLongChapter`（长按分章）、`ToggleDeleteAlert`（删除确认）三项不占独立行，理由写在该块小结里。

## A 书架主屏

上游主体：`legado-with-MD3/app/src/main/java/io/legado/app/ui/main/bookshelf/BookshelfScreen.kt`（1872 行）、`BookItem.kt`、`GroupManageSheet.kt`、`BookshelfConfigSheet.kt`、`domain/model/settings/BookshelfSettings.kt`（52 字段）。
本地主体：`entry/src/main/ets/pages/BookshelfPage.ets`（729 行）、`components/BookCover.ets`、`model/BookshelfLayout.ets`。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 顶栏标题与滚动折叠 | `BookshelfScreen.kt:1359` | `BookshelfPage.ets:604-625` | 已接 | 上游标题取 `uiState.title`，本地固定「书架」 | 滚动 60vp 后标题收起 | — |
| 书架内搜索（书名/作者） | `BookshelfScreen.kt:1341` | `BookshelfPage.ets:611-615,627-636` | 已接 | 上游进全局搜索页，本地就地过滤 | 输入书名只剩匹配卡片 | 上游 `bookshelfSearchActionDirectToSearch` 未建模 |
| 顶栏「更多」菜单 | `BookshelfScreen.kt:698-775` | `BookshelfPage.ets:616-618,573-602` | 已接 | 同 11 项，序号与文案一致 | 点开菜单见 11 项 | — |
| 分组页签筛选与切换 | `BookshelfScreen.kt:820` | `BookshelfPage.ets:639-645` | 已接 | — | 点页签只剩该分组书 | `bookGroupStyle=0` |
| 隐藏分组页签 | `BookshelfSettings.kt:6` | `BookshelfPage.ets:514-516,646-652` | 已接 | 隐藏后改由「切换分组」进分组面板 | 开关后顶部页签消失 | — |
| 隐藏没有书籍的分组 | `BookshelfSettings.kt:7` | `BookshelfPage.ets:517-519,68-88` | 已接 | 只对自定义分组生效，「全部」与「本地未分组」恒显示 | 空分组从页签消失 | 上游同样豁免系统分组 |
| 卡片点击打开书籍 | `BookshelfScreen.kt:1777` | `BookshelfPage.ets:668-674` | 已接 | `bodyMissing` 时改开详情 | 点未损书进阅读 | — |
| 卡片长按进详情 | `BookItem.kt:738` | `BookshelfPage.ets:675-677` | 已接 | 500ms 长按 | 长按弹出详情页 | — |
| 封面 + 书名网格 | `BookshelfScreen.kt:1752` | `BookshelfPage.ets:654-682` | 已接 | 列数由布局设置算 | 网格内出现书封与书名 | — |
| 书封阴影 | `BookshelfSettings.kt:47` | `BookshelfPage.ets:551-552,662` | 已接 | — | 开关后书封投影变化 | — |
| 书名最大行数 | `BookshelfSettings.kt:46` | `BookshelfPage.ets:546-548,665` | 已接 | 范围 1–5 | 长书名被截断行数变化 | — |
| 网格列数 | `BookshelfSettings.kt:28` | `BookshelfPage.ets:537-540` | 已接 | 范围 1–6 | 每行列数变化 | 上游还有横屏键，未建模 |
| 列表列数 | `BookshelfSettings.kt:31` | `BookshelfPage.ets:541-545` | 已接 | 范围 1–5 | 切列表模式后列数变化 | — |
| 布局模式（网格/列表） | `BookshelfSettings.kt:27` | `BookshelfPage.ets:527-536` | 已接 | 只有竖屏键 | 切换后布局形态变化 | 横屏两组键未建模 |
| 排序方式 | `BookshelfSettings.kt:8` | `BookshelfPage.ets:522-523` | 已接 | 取值与上游 `bookshelfSort` 对齐 | 切「最近阅读」后顺序变化 | 全档未逐档验证 |
| 排序方向 | `BookshelfSettings.kt:9` | `BookshelfPage.ets:524-525` | 已接 | 升/降两种 | 切「降序」后顺序反转 | — |
| 空态文案与表情 | `BookshelfScreen.kt:980,1680,1692` | `BookshelfPage.ets:692-702` | 已接 | 本地三态文案（无书/无匹配/空分组） | 清空书架后见空态 | 上游另有全局搜索空态 |
| 分组书籍数量 | `BookshelfScreen.kt:1013`（`book_count`） | — | 未接 | 分组标题不显示「N 本」 | 分组页签或标题出现本数 | `showBookCount` 未建模 |
| 未读章节数角标 | `BookItem.kt:752`（`showUnread`） | — | 未接 | `BookCover.ets:43` 只显示总章数，无未读数 | 卡片角标显示未读章数 | `showUnread`/`showUnreadNew` 均未建模 |
| 更新角标 | `BookItem.kt:753`（`book.isNew`） | — | 未接 | `Book.ets` 无 `isNew` 字段 | 有更新书出现红点 | 需先落 `isNew` |
| 卡片进度百分比与进度条 | `BookItem.kt:942` | — | 未接 | `Book.progress` 已存但卡片不渲染 | 卡片出现百分比或进度条 | 详情页已渲染（B-11） |
| 卡片最新章节名 | `BookItem.kt:942`（`bookshelfShowLatestChapter`） | — | 未接 | `Book.lastChapter` 已存但卡片不显示 | 卡片出现章节名 | — |
| 卡片上次更新时间 | `BookItem.kt:944`（`showLastUpdateTime`） | — | 未接 | `Book.latestChapterTime` 已存但无格式化与展示 | 卡片出现相对时间 | — |
| 卡片简介 | `BookItem.kt:738-739`（`showBookIntro`） | — | 未接 | 列表模式不显示简介 | 列表模式出现简介 | 依赖列表模式落地 |
| 卡片自定义标签 | `BookItem.kt:878-888`（`bookshelfShowCustomTags`） | — | 未接 | `Book.customTag` 已存但卡片不渲染 | 卡片出现自定义标签 | — |
| 卡片来源标签 | `BookItem.kt:878-888`（`bookshelfShowSourceTags`） | — | 未接 | `Book.ets` 无 `origin`/`originName` | 卡片出现来源名 | 需先落来源字段 |
| 卡片字数 | `BookItem.kt:878-888`（`bookshelfShowWordCount`） | — | 未接 | `Book.ets` 无 `wordCount` | 卡片出现字数 | 需先落字数 |
| 快速滚动条 | `BookshelfScreen.kt:987,1752`（`FastScrollLazyVerticalGrid`） | — | 未接 | 书架无滚动条，`scrollBar(BarState.Off)` | 长列表出现拖动条 | `showBookshelfFastScroller` 未建模 |
| 拖拽排序 | `BookshelfScreen.kt:1731,1783` | — | 未接 | 卡片无 `onDrag`，`Book.order` 已存但不可改 | 长按拖动改变顺序并持久化 | 依赖 `bookshelfSort` 为手动档 |
| 选择模式（进入/计数） | `BookshelfScreen.kt:392,1223,1231` | `BookshelfPage.ets:591-592` | 未接 | 菜单项直接提示「尚未迁移」 | 点「选择模式」进多选态并显示已选数 | — |
| 全选/反选 | `BookshelfScreen.kt:614,621` | — | 未接 | 依赖选择模式 | 编辑态出现全选与反选 | — |
| 批量下载 | `BookshelfScreen.kt:1534` | — | 未接 | 依赖选择模式 | 选中后出现下载项 | 本地无在线书源，暂不可验 |
| 批量移动到分组 | `BookshelfScreen.kt:1477` | — | 未接 | 依赖选择模式 | 选中后移到目标分组 | — |
| 批量删除（含删原文件） | `BookshelfScreen.kt:1543,1567` | — | 未接 | 依赖选择模式 | 选中后删除并询问原文件 | — |
| 远程书籍（网络导入） | `BookshelfScreen.kt:695` | `BookshelfPage.ets:576-577` | 未接 | 提示「远程书籍导入尚未迁移」 | 打开网络书库页并可导入 | 依赖书源 |
| 添加本地 | `BookshelfScreen.kt:700` | `BookshelfPage.ets:578-582` | 已接 | 成功后回落「全部」 | 选 TXT/EPUB 后上架 | — |
| 更新目录（书架级） | `BookshelfScreen.kt:705` | `BookshelfPage.ets:583-584` | 已接 | 逐个本地书重切目录 | 书架菜单触发后目录刷新 | — |
| 布局设置面板 | `BookshelfScreen.kt:713` | `BookshelfPage.ets:585-586,502-556` | 已接 | 9 项，上游 52 字段 | 打开面板见四组设置 | 差异见下文「设置项缺口」 |
| 分组管理面板 | `BookshelfScreen.kt:721` | `BookshelfPage.ets:587-588,218-388` | 已接 | 新建/改名/排序/封面/显隐/私有/刷新 | 新建分组后页签出现 | 上游另有 AI 分组与标签同步 |
| 添加网址 | `BookshelfScreen.kt:729` | `BookshelfPage.ets:589-590` | 未接 | 提示「网址导入尚未迁移」 | 粘网址后上架 | 依赖书源 |
| 书架管理 | `BookshelfScreen.kt:745` | `BookshelfPage.ets:593-594` | 未接 | 提示「书架管理尚未迁移」 | 进入管理页 | 上游为独立子页 |
| 导出书单 | `BookshelfScreen.kt:756` | `BookshelfPage.ets:595-596` | 未接 | 提示「书单导出尚未迁移」 | 导出可分享的书单文件 | 上游有 `import_bookshelf`/`export_bookshelf` 两个 dialog |
| 导入书单 | `BookshelfScreen.kt:764` | `BookshelfPage.ets:597-598` | 未接 | 提示「书单导入尚未迁移」 | 选书单文件后批量上架 | — |
| 日志 | `BookshelfScreen.kt:772` | `BookshelfPage.ets:599-600` | 未接 | 提示「日志界面尚未迁移」 | 进入日志页 | — |
| 下拉刷新 | `BookshelfConfigSheet.kt`（`autoRefreshBook`） | `BookshelfPage.ets:336-340` | 未接 | 分组面板有「下拉刷新」开关，但只存兼容标记，书架本身无下拉手势 | 下拉出现刷新态 | 面板文案已自述「不控制实际更新」 |

### 设置项缺口（A 块汇总）

上游 `domain/model/settings/BookshelfSettings.kt:5-57` 共 52 字段，本地 `model/BookshelfLayout.ets:59-69` 的 `DEFAULT_BOOKSHELF_LAYOUT` 只有 9 字段：
`bookGroupStyle`、`hideEmptyGroups`、`bookshelfSort`、`bookshelfSortOrder`、`bookshelfLayoutModePortrait`、`bookshelfLayoutGridPortrait`、`bookshelfLayoutListPortrait`、`bookshelfTitleMaxLines`、`bookshelfCoverShadow`。

未建模 43 项中，影响 A 块可见行为的是：`showUnread`、`showUnreadNew`、`showTip`、`showBookCount`、`showLastUpdateTime`、`showBookIntro`、`bookshelfShowIntro`、`bookshelfShowTag`、`bookshelfShowCustomTags`、`bookshelfShowSourceTags`、`bookshelfShowWordCount`、`bookshelfShowLatestChapter`、`bookshelfShowFastScroller`、`bookshelfShowDivider`、`bookshelfTitleSmallFont`、`bookshelfTitleCenter`、`bookshelfCardColor`、`bookshelfListCoverWidth`、`bookshelfGridCoverWidth`、`autoRefreshBook`；横屏与文件夹共 12 项 `bookshelfFolder*`/`*Landscape` 键本地无横屏布局，属后续轮次；`saveTabPosition`、`bookshelfRefreshingLimit`、`shouldShowExpandButton`、`bookshelfLayoutCompact`、`bookshelfListIntroBelowContent`、`bookshelfListCoverCenter`、`bookshelfGridLayout`、`bookshelfGroupListStyle`、`bookshelfGroupCoverCount`、`bookshelfSearchActionDirectToSearch`、`showWaitUpCount`、`bookshelfCardColorDark`、`bookshelfLayoutGridLandscape` 等依赖尚未迁移的视图形态。

## B 书籍元数据

上游：`ui/book/info/BookInfoScreen.kt`、`ui/book/info/BookInfoContract.kt:376-397`（`BookInfoMenuAction` 20 项）、`data/entities/Book.kt:41-139`。
本地：`entry/src/main/ets/pages/BookInfoPage.ets`（430 行）、`pages/Index.ets:3014-3076 saveBookMetadata`、`model/Book.ets`。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 打开书籍详情 | `BookInfoScreen.kt:764` | `Index.ets:2848` | 已接 | 书架点击/长按进入 | 详情页显示封面与简介 | — |
| 返回 | `BookInfoScreen.kt:764` | `BookInfoPage.ets:262-266` | 已接 | 滚动后顶栏变实底 | 返回书架 | — |
| 编辑（元数据编辑器） | `BookInfoContract.kt:378`、`BookInfoScreen.kt:886` | `BookInfoPage.ets:268`→`Index.ets:3014` | 已接 | 9 个可编辑字段 | 改名后书架同步 | 仅本地书可存 |
| 分享 | `BookInfoContract.kt:379`、`BookInfoScreen.kt:892` | `BookInfoPage.ets:269` | 未接 | 提示「书籍分享尚未迁移」 | 弹出分享面板 | — |
| 更多菜单 | `BookInfoContract.kt:377-397`、`BookInfoScreen.kt:911` | `BookInfoPage.ets:270` | 未接 | 提示「书籍更多操作尚未迁移」，20 项无入口 | 点「更多」出现菜单 | 见下方 11 条 |
| 动作行·已在书架/移出 | `BookInfoScreen.kt:338` | `BookInfoPage.ets:190-194` | 已接 | `bodyMissing` 文案改为「移出缺正文记录」 | 移出后书架少一本 | — |
| 动作行·查看目录 | `BookInfoScreen.kt`（`CatalogClick`） | `BookInfoPage.ets:195` | 已接 | 跳目录页 | 打开目录 | — |
| 动作行·换源 | `BookInfoScreen.kt`（`ChangeSource`） | `BookInfoPage.ets:196` | 未接 | 提示「在线换源将在 P5 接入」 | 弹出书源列表 | 依赖书源 |
| 动作行·阅读记录 | `BookInfoContract.kt:383` | `BookInfoPage.ets:197`→`Index.ets:3709,3755` | 已接 | 进 READ_RECORDS 子页 | 打开阅读记录 | `ReadRecordRepository` 已接三层 |
| 元数据·书名 | `Book.kt:57` | `BookInfoPage.ets:30,268` | 已接 | — | 改名后书架与详情同步 | — |
| 元数据·作者 | `Book.kt:60` | 同上 | 已接 | — | 改作者后搜索可命中 | — |
| 元数据·分类 | `Book.kt:62`（`kind`） | 同上 | 已接 | 本地用单值 `category`，上游 `kind` 可为列表 | 改分类后分组/筛选变化 | 多值 kind 未建模 |
| 元数据·简介 | `Book.kt`（`intro`） | `BookInfoPage.ets:33,237-246` | 已接 | 空简介有分本地/在线两种空态文案 | 改简介后详情更新 | — |
| 元数据·备注 | `Book.kt`（`remark`） | `BookInfoPage.ets:34,247-252` | 已接 | — | 改备注后详情更新 | — |
| 元数据·自定义标签 | `Book.kt:64`（`customTag`） | `BookInfoPage.ets:35,180-182` | 已接 | 逗号分隔拆标签 | 加标签后详情出现徽标 | 卡片不显示（A-25） |
| 元数据·多分组 | `Book.kt`（`groupNames`） | `BookInfoPage.ets:36` | 已接 | 多选分组 | 加入两个分组后两处都能见 | — |
| 元数据·书籍类型 | `Book.kt`（`kind`/媒体类型） | `BookInfoPage.ets:37` | 已接 | `text`/`audio`/`image` 三值 | 改成音频后阅读入口变化 | `BookMediaType` 见 `Book.ets:27` |
| 元数据·固定类型 | 上游 `Book.kt`（推断固定项） | `BookInfoPage.ets:38` | 已接 | 布尔开关 | 固定后重导入不改类型 | — |
| 封面·选择本地图片 | `BookInfoScreen.kt`（`SetCover`） | `BookInfoPage.ets:19`→`Index.ets:3102` | 已接 | 复制到应用私有目录 | 换封面后书架与详情同步 | 冷启还原未实测 |
| 封面·恢复原封面 | `BookInfoScreen.kt`（`SetCover`） | `BookInfoPage.ets:20`→`Index.ets:3119` | 已接 | 清 `customCoverUri` 回落 EPUB 原封面 | 还原后显示原封面 | — |
| 显示·在读/最新章节 | `BookInfoScreen.kt:467-469` | `BookInfoPage.ets:201-204` | 已接 | 两行文案 | 读过之后显示「在读」 | — |
| 显示·共 N 章 / 已读 N 章 | `BookInfoScreen.kt`（`bookInfo` 概览） | `BookInfoPage.ets:205-211` | 已接 | 章数未知时显示「章节总数待读取」 | 显示章数与已读数 | — |
| 显示·进度条 | `BookInfoScreen.kt`（进度区） | `BookInfoPage.ets:212-216` | 已接 | 百分比按 `Book.progress` | 读过一半进度条约半 | — |
| 显示·缺正文提示卡 | — | `BookInfoPage.ets:220-232` | 已接 | 上游无对应卡，本地为 Android 备份恢复专用 | 恢复缺正文记录时见提示 | 本地增量，非上游项 |
| 菜单·置顶 | `BookInfoContract.kt:386`（`Top`） | — | 未接 | `Book.ets` 无置顶字段 | 置顶后排最前 | 需先落字段 |
| 菜单·允许更新 | `BookInfoContract.kt:391`（`ToggleCanUpdate`） | — | 未接 | `Book.ets` 无 `canUpdate` | 关闭后更新目录跳过本书 | 需先落字段 |
| 菜单·禁止阅读记录 | `BookInfoContract.kt:384`（`ToggleReadRecordDisabled`） | — | 未接 | 本地阅读记录无按书开关 | 关闭后该书不写记录 | — |
| 菜单·复制书籍/目录链接 | `BookInfoContract.kt:389-390` | — | 未接 | 本地无 `bookUrl`/`tocUrl` 概念 | 复制后剪贴板有值 | 本地书为本地路径 |
| 菜单·设为私密 | `BookInfoContract.kt:397`（`TogglePrivate`） | — | 未接 | 书架「私有分组」只存标记不生效 | 私密书需密码打开 | `BookshelfPage.ets:256` 已自述「私有标记未生效」 |
| 菜单·清除缓存 | `BookInfoContract.kt:394`（`ClearCache`） | — | 未接 | 本地无正文缓存层 | 清除后重新解析正文 | — |
| 菜单·刷新书籍信息 | `BookInfoContract.kt:382`（`Refresh`）、`BookInfoScreen.kt:1054` | — | 未接 | 本地无在线信息刷新 | 刷新后简介更新 | 依赖书源 |
| 菜单·书籍变量/书源变量 | `BookInfoContract.kt:387-388` | — | 不适用 | 本地无书源与变量求值引擎，[项目队列](../PROJECT.md) 范围内不含 | — | 随书源体系一并评估 |
| 菜单·登录 | `BookInfoContract.kt:385`（`Login`） | — | 不适用 | 依赖书源账号体系，本地无条件 | — | 随书源体系一并评估 |
| 菜单·WebDAV 同步/上传/日志 | `BookInfoContract.kt:381,380,395`、`BookInfoScreen.kt:1070-1076` | — | 不适用 | 本地同步走 ZIP 备份（`BackupRepository`），不走 WebDAV | — | 由备份模块覆盖 |

**B 块小结**：20 个 `BookInfoMenuAction` 中，`Edit` 与 `ReadRecord` 已接；`Top`、`ToggleCanUpdate`、`ToggleReadRecordDisabled`、`CopyBookUrl`、`CopyTocUrl`、`TogglePrivate`、`ClearCache`、`Refresh` 未接；`Login`、`Upload`、`SyncRemote`、`ShowLog` 因无对应基础设施判为不适用；`CustomButton`（书源自定义按钮）、`ToggleSplitLongChapter`（长按分章开关）、`ToggleDeleteAlert`（删除前确认开关）三项本地无书源与分章体系，随书源体系一并评估，不单独占行。

**字段缺口**：上游 `Book.kt:41-139` 有而 `model/Book.ets` 没有的字段：`bookUrl`、`tocUrl`、`origin`、`originName`、`kind`、`totalChapterNum`、`latestChapterTitle`、`wordCount`、`canUpdate`、`variable`、`readConfig`、`syncTime`、`infoHtml`、`isNew`、`customCoverUrl`（本地用 `customCoverUri`）、`durChapterTitle`（本地用 `lastChapter`）、`durChapterPos`（本地用 `chapterProgress`）。本地另有上游无的补偿字段：`contentPath`、`format`、`charset`、`reSegment`、`fileSizeBytes`、`bodyMissing`、`androidOriginalPath`、`androidCharacterPosition`、`readerPositionVersion`、`tocRule`、`imageStyle`。

## C 阅读进度

上游：`data/entities/Book.kt` 进度字段、`data/repository/ReadRecordRepository.kt`、`ui/book/read/`。
本地：`pages/Index.ets:3206-3272 updateReadingProgress`、`model/ReadRecord.ets`、`data/ReadRecordRepository.ets`。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 保存当前章节序号 | `Book.kt`（`durChapterIndex`） | `Index.ets:3212-3213,3226` | 已接 | 越界时收敛到章节区间 | 翻到第 5 章后重开在第 5 章 | — |
| 保存章内百分比 | `Book.kt`（`durChapterPos`） | `Index.ets:3215,3227` | 已接 | 0–100，本地名 `chapterProgress` | 停在章中后重开位置一致 | — |
| 保存当前章节名 | `Book.kt`（`durChapterTitle`） | `Index.ets:3228` | 已接 | 本地复用 `lastChapter` | 书架/详情显示当前章名 | 与「最新章节名」共用一个字段，是已知语义混用 |
| 计算并保存总进度百分比 | 上游据章节数换算 | `Index.ets:3229` | 已接 | `(chapterIndex + cp/100)/chapterCount*100` | 详情页进度条与百分比一致 | — |
| 保存上次阅读时间 | `Book.kt`（`durChapterTime`） | `Index.ets:3254` | 已接 | 每次写进度即刷新，驱动「最近阅读」排序 | 切排序方式顺序变化 | — |
| 精确保存字符位置 | 上游 `durChapterPos` 字符级 | `Index.ets:3248` | 已接 | 本地另存 `androidCharacterPosition` | 重开位置逐字一致 | — |
| 阅读位置版本标记 | — | `Index.ets:3249-3250` | 已接 | Android 坐标为 2，本地为 0 | 混入 Android 备份后不串位 | 本地增量 |
| 打开书籍恢复阅读位置 | `Book.kt` | `Index.ets:3683` | 已接 | 读取三字段还原 | 杀掉进程重开仍在上次位置 | — |
| 阅读记录写入（三层汇总） | `ReadRecordRepository.kt` | `ReadRecordRepository.ets`、`ReadRecord.ets:9-19` | 已接 | preferences 存三段文本协议，字段语义与上游对齐 | 读完后记录页出现该书 | `deviceId` 本地恒空串 |
| 阅读记录按日明细 | `ReadRecordRepository.kt:412` | `ReadRecord.ets:21-40` | 已接 | `readWords` 实际存章节序号累加，按上游行为照做 | 记录页时间线出现当日条目 | 上游同名注释有误导，已在代码注释说明 |
| 阅读时段 session | `ReadRecordRepository.kt` | `ReadRecord.ets`（`ReadRecordSession`） | 已接 | 三层模型齐备 | 记录页可看单次时长 | — |
| 跨午夜会话切分 | `ReadRecordRepository.kt` | `ReadRecord.ets:28-29` 注释所述 | 已接 | 按午夜切开累加 | 跨 0 点阅读后两天都有时长 | — |
| 阅读记录查看页 | `BookInfoMenuAction.ReadRecord` | `Index.ets:3709,3755` | 已接 | 详情页动作行第四项进入 | 打开记录页见列表 | 别名合并、字数采集仍未完成 |
| 备份导出进度字段 | `help/storage/Backup.kt` | `BackupRepository.ets` | 已接 | `bookshelf.json` 写进度字段 | 导出 ZIP 含进度 | 见 `parity/STATUS.md:30` |
| 备份恢复进度字段 | `help/storage/Backup.kt` | `BackupRepository.ets` | 已接 | 恢复后位置与进度可用 | 导入 Android ZIP 后位置一致 | 缺正文书走 `bodyMissing` |
| 书架卡片显示阅读进度 | `BookItem.kt:942` | — | 未接 | 同 A 块「卡片进度百分比与进度条」，卡片不渲染进度 | 卡片出现进度 | — |
| 详情页显示进度 | `BookInfoScreen.kt` | `BookInfoPage.ets:212-216` | 已接 | 同 B 块「显示·进度条」 | 详情页进度条 | — |

## 结论

1. **书架主屏的骨架齐、展示薄**：菜单 11 项中 4 项可用，布局与分组两个面板可用，但卡片只显示封面与书名——未读角标、进度、最新章节、标签、字数全部未接，上游 `BookItem.kt` 的展示层基本没迁。
2. **书架缺三类交互体系**：选择模式（含全选/批量下载/移动/删除）、拖拽排序、快速滚动条。三者都依赖上游已建模而本地未建模的设置键与手势框架。
3. **元数据编辑已可用但入口只有一处**：编辑面板 9 字段可用，上游 20 个详情页菜单动作只接了 2 个，其余多数依赖尚未落地的书籍字段（`canUpdate`、`isNew`、`origin`、`wordCount`、置顶项）。
4. **进度是本模块最完整的一块**：写入链路、恢复链路、阅读记录三层、备份往返都已接；主要缺口只在卡片展示（与 A 块重合）。

## 建议后续顺序

1. 先补 `Book.ets` 缺字段（`isNew`、`canUpdate`、`origin`/`originName`、`wordCount`、置顶项）—— 直接解锁 A 块「更新角标」「卡片来源标签」「卡片字数」3 条与 B 块「菜单·置顶」「菜单·允许更新」2 条，共 5 条。
2. 再落卡片展示（未读角标、进度、最新章节、上次更新时间、简介、自定义标签）与书架分组计数，这些字段本地已有、只是没渲染，风险低，一次可清 7 条。
3. 然后做选择模式与拖拽排序（需先补 `bookshelfSort` 手动档与 `Book.order` 可写），连带清掉全选/批量下载/移动/删除 5 条。
4. 书源相关项（远程书籍、添加网址、换源、刷新信息、批量下载）等书源体系落地后统一处理。
5. 书单导入导出、书架管理、日志、分享四项是独立子页或独立能力，可各开一轮。

## 维护

本表按模块维度组织，与 [ZIP 类别总账](STATUS.md) 的类别维度正交：`localBook` 类别的 `bookshelf.json` 往返见该表，本表覆盖书架 UI 与元数据/进度的全部用户可感操作。改本表时同步检查 [`STATUS.md:30`](STATUS.md) 的 `localBook` 行链接是否仍指向本文件。
