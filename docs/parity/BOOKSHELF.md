# 书架 / 书籍元数据 / 进度 对照表

本表按 [模块对照要求](../CODE-CONVENTIONS.md) 第四节一次盘完，行粒度是一次用户可感知的操作。
状态三值：`已接` / `未接` / `不适用`；`不适用` 必写理由。**本表无 `待定` 行。**

- 盘点日期：2026-10-30（r279 重盘，作废 r277 的 96 行版；r280 二轮补漏）
- 上游基线：`N:\HarmonyProjects\legado-with-MD3`（Android，Compose），路径均相对 `app/src/main/java/io/legado/app/`
- 本地实现：`N:\HarmonyProjects\legado-with-md3-harmonyos`，路径均相对 `entry/src/main/ets/`

## 为什么重盘

r277 版 96 行（58 已接 / 35 未接 / 3 不适用）作废，原因是**以本地代码为索引反推上游**：本地没有的词永远检索不到，于是「本地压根没有」的能力被系统性漏掉。重盘改为先 `grep -rl` 枚举上游接触面全清单，再拿清单对本地。

重盘补出的主要漏项：AI 自动分组、标签匹配规则与同步、分组四宫格预览与计数、文件夹根视图（`bookGroupStyle == 2` 第三档）、卡片未读角标 / 更新红点 / 更新中指示 / 类型标签 / 来源标签 / 自定义标签 / 简介 / 更新时间 / 最新章节、选择模式七件套、私密分组与解锁、书架设置 44 个一级控件、详情页 20 个菜单动作中的 15 项、简介四分支渲染、角色 / 知识 / 事件卡、阅读记录热力图与图表与合并同名。

## 为什么还要二轮补漏

r279 版 220 行仍是按「用户可感知的操作」取粒度，漏掉的是**同一区域内的次级交互**：长按、副标题、可点的文字元素、面板内的分区。r280 换了两条独立线索交叉验证：

1. 把上游四个目录的 30 个 `.kt` 文件全列一遍，挑出 r279 未覆盖的 14 个（共 3669 行）逐个核对——`BookshelfViewModel.kt`(1436)、`BookInfoViewModel.kt`(2164)、`BookInfoSheets.kt`(297)、`ShelfDeleteSheet.kt`(182)、`BookInfoReadRecordSheet.kt`(167)、`ReadRecordOverviewScreen.kt`(547) 等。
2. 把详情页 130 个 `R.string.*` 键与表中文字做差集，未出现的键逐个回查调用点。

补出 40 条：A1 15 条（顶栏 8、空态与分页 2、卡片 5）、B 20 条（头部 7、动作卡拆分 1、面板与脚本 10、删除面板 2）、C 5 条（总览页分区）。

其中一条是**状态判错而非漏列**：r279 把「动作卡·阅读记录」判为已接，但上游是本书专属的内嵌面板（`BookInfoReadRecordSheet.kt:41-116`），本地 `pages/BookInfoPage.ets:197` 点开跳的是全局阅读记录页。r280 拆成「入口已接」+「面板未接」两行。

## 盘面

| 块 | 条数 | 已接 | 未接 | 不适用 |
| --- | --- | --- | --- | --- |
| A1 书架主屏与卡片 | 78 | 15 | 63 | 0 |
| A2 书架设置面板 | 48 | 9 | 39 | 0 |
| A3 分组管理 | 22 | 13 | 9 | 0 |
| B 书籍详情页与元数据 | 80 | 22 | 57 | 1 |
| C 阅读进度与记录 | 32 | 17 | 15 | 0 |
| 合计 | 260 | 76 | 183 | 1 |

---

## A1 书架主屏与卡片

上游主体：`ui/main/bookshelf/BookshelfScreen.kt`（1872 行）、`BookItem.kt`（1090 行）、`BookShelfItem.kt`。
本地主体：`pages/BookshelfPage.ets`（729 行）、`components/BookCover.ets`（85 行）。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 顶栏标题随滚动折叠 | `BookshelfScreen.kt:1329` | `pages/BookshelfPage.ets:606-625` | 已接 | 本地阈值 60vp，折叠动画 220ms | 书架下滑超过一屏，大标题淡出、顶栏出现小标题 | — |
| 顶栏搜索入口 | `BookshelfScreen.kt:1329` | `pages/BookshelfPage.ets:611-613` | 已接 | 本地为内联展开输入框，非独立搜索页 | 点搜索图标出现输入框，输入书名可过滤 | — |
| 搜索按钮长按切换为筛选 | `BookshelfScreen.kt:1342` | `pages/BookshelfPage.ets:611-615` | 未接 | 本地只有单击开搜索，无长按分支 | 长按搜索图标后按钮变成「筛选」，再点开筛选面板 | 受 `bookshelfSearchActionDirectToSearch` 决定主次动作 |
| 顶栏独立筛选入口 | `BookshelfScreen.kt:1342` | — | 未接 | 本地筛选只有页签，无独立按钮 | 顶栏出现筛选按钮，点开筛选面板 | `bookshelf_filter` |
| 顶栏标题随分组/搜索/编辑态变化 | `BookshelfViewModel.kt:921-947` | `pages/BookshelfPage.ets:608`、`:621` | 未接 | 本地恒为「书架」 | 切到「科幻」分组后标题变成「科幻」，有更新书时追加 `(N)` | `buildTitle()` 四分支 |
| 顶栏副标题 | `BookshelfViewModel.kt:676-698` | — | 未接 | 本地无副标题 | 编辑态显示「已选 N / 共 M」，搜索态显示总数 | — |
| 标题加载中字符闪烁 | `BookshelfScreen.kt:1364` | — | 未接 | 本地加载态无标题动画 | 书架加载时标题显示「加载中」并逐字闪烁 | `useCharMode` |
| 搜索栏展开/收起动画与清空按钮 | `BookshelfScreen.kt:1379-1395` | `pages/BookshelfPage.ets:627-636` | 未接 | 本地为普通 `TextInput` 直接显隐，无动画、无清空按钮 | 点搜索图标时搜索栏滑出，输入后出现清空按钮 | 上游 `AnimatedVisibility` + `SearchBar` |
| 编辑态顶栏关闭按钮 | `BookshelfScreen.kt:1355` | — | 未接 | 本地无编辑态 | 进入选择模式后顶栏左侧变成关闭按钮，点后退出并清空选择 | `cancel_select` |
| 顶栏更多菜单 | `BookshelfScreen.kt:688` | `pages/BookshelfPage.ets:614-617`、`:574-601` | 已接 | 本地用 `bindMenu` 弹 Menu，上游为 ModalBottomSheet | 点更多图标弹出 11 项菜单 | — |
| 更多菜单·远程书籍 | `BookshelfScreen.kt:695` | `pages/BookshelfPage.ets:576` | 未接 | 本地 `onUnavailableAction('远程书籍导入尚未迁移')` | 点该菜单项弹出导入对话框并成功导入 1 本 | 依赖网络书库协议 |
| 更多菜单·添加本地 | `BookshelfScreen.kt:700` | `pages/BookshelfPage.ets:578` | 已接 | 本地走系统文件选择器导入 TXT | 选 1 个 TXT，书架新增该书并自动分组「本地未分组」 | — |
| 更多菜单·更新目录 | `BookshelfScreen.kt:705` | `pages/BookshelfPage.ets:583` | 已接 | 本地重识别全部本地 TXT 目录 | 点后目录章数变化，书签与划线保持原章节号 | 见 r276 |
| 更多菜单·布局设置 | `BookshelfScreen.kt:713` | `pages/BookshelfPage.ets:586` | 已接 | 打开同一 sheet 的布局面板 | 点后弹出「书架布局」面板 | — |
| 更多菜单·分组管理 | `BookshelfScreen.kt:721` | `pages/BookshelfPage.ets:588` | 已接 | 打开同一 sheet 的分组面板 | 点后弹出分组管理网格 | — |
| 更多菜单·添加网址 | `BookshelfScreen.kt:729` | `pages/BookshelfPage.ets:590` | 未接 | 本地 `onUnavailableAction('网址导入尚未迁移')` | 粘贴网址后成功建立书籍条目 | — |
| 更多菜单·选择模式 | `BookshelfScreen.kt:737` | `pages/BookshelfPage.ets:592` | 未接 | 本地 `onUnavailableAction('书架选择模式尚未迁移')` | 进入选择模式后卡片出现勾选框 | 缺口见本块下方七条 |
| 更多菜单·书架管理 | `BookshelfScreen.kt:745` | `pages/BookshelfPage.ets:594` | 未接 | 本地 `onUnavailableAction('书架管理尚未迁移')` | 打开书架管理页并可批量清理 | — |
| 更多菜单·导出书单 | `BookshelfScreen.kt:756` | `pages/BookshelfPage.ets:596` | 未接 | 本地 `onUnavailableAction('书单导出尚未迁移')` | 导出文件可被上游阅读 App 导入 | — |
| 更多菜单·导入书单 | `BookshelfScreen.kt:764` | `pages/BookshelfPage.ets:598` | 未接 | 本地 `onUnavailableAction('书单导入尚未迁移')` | 导入上游导出的书单后书架条目数增加 | — |
| 更多菜单·日志 | `BookshelfScreen.kt:772` | `pages/BookshelfPage.ets:600` | 未接 | 本地 `onUnavailableAction('日志界面尚未迁移')` | 打开日志页并看到近期错误条目 | — |
| 分组页签栏 | `BookshelfScreen.kt:780-900` | `pages/BookshelfPage.ets:639-647` | 已接 | 本地为横排 `ShelfFilter` 列表，无页签下划线动画 | 多个分组时顶部出现分组名横排，点切换过滤 | `bookGroupStyle == 0` 时渲染 |
| 页签栏右侧分组管理按钮 | `BookshelfScreen.kt:820` | — | 未接 | 本地页签栏右侧无按钮，只能走更多菜单 | 页签栏右端出现图标，点开分组管理 | — |
| 隐藏页签模式下的「切换分组」 | `BookshelfScreen.kt:900-980` | `pages/BookshelfPage.ets:648-652` | 已接 | 本地显示「当前分组：X」+「切换分组」文字按钮 | 打开「隐藏分组页签」后，点「切换分组」可切换 | `bookGroupStyle != 0` 时渲染 |
| 分组样式第三档「文件夹」 | `BookshelfScreen.kt:983` | `model/BookshelfLayout.ets` | 未接 | `BOOK_GROUP_STYLE_OPTIONS` 只有 `{0,页签}`/`{1,隐藏页签}`，缺第三项 | 布局面板出现「文件夹」选项，选中后书架变文件夹根视图 | 结构性缺口，牵动本块后三条 |
| 文件夹根视图（分组即一级条目） | `BookshelfScreen.kt:983-1070` | — | 未接 | 本地无 `BookGroupItemList`/`BookGroupItemGrid` 等价物 | 选中文件夹样式后，书架按分组显示，点分组进二级书列表 | — |
| 文件夹四宫格封面预览 | `BookshelfScreen.kt:1028-1032`、`BookItem.kt:361-432` | — | 未接 | 本地分组卡片只有一个封面或加号 | 文件夹卡片显示前 4 本书的封面拼图 | 数量由 `bookshelfGroupCoverCount` 控制 |
| 文件夹书籍计数角标 | `BookshelfScreen.kt:1019-1027`、`BookItem.kt:437-447` | — | 未接 | 本地分组卡片无计数 | 文件夹卡片右上角显示「N 本」 | `showBookCount` 为 true 且分组未锁定时显示 |
| 文件夹长按进分组编辑 | `BookshelfScreen.kt:1055` | `pages/BookshelfPage.ets:259` | 未接 | 本地长按入口在分组管理面板内，不在书架 | 文件夹卡片长按直接打开分组编辑表单 | 面板内已接，缺书架入口 |
| 书封渲染（含占位与灰底） | `BookItem.kt:738-800` | `components/BookCover.ets:77-78` | 已接 | 本地尺寸 92×128 / compact 70×100 / mini 48×68 | 无封面书籍显示按书名生成的占位图 | — |
| 卡片副标题作者行 | `BookItem.kt:866` | `pages/BookshelfPage.ets:664-666` | 未接 | 本地卡片只有书名，无作者行 | 卡片书名下显示作者 | — |
| 紧凑模式「作者 · N 未读」副标题 | `BookItem.kt:866` | — | 未接 | 本地无紧凑模式，也无未读数 | 开启紧凑模式后副标题变成「作者 · 3 未读」 | `author_read` |
| 列表卡片描述行显示当前章 | `BookItem.kt:871` | — | 未接 | 本地卡片无当前章描述 | 列表模式卡片显示「第 12 章 章节名」 | `durChapterTitle` |
| 标题区未读徽标叠加更新图标 | `BookItem.kt:853-865` | — | 未接 | 本地 `titleEnd` 插槽无实现 | 有更新的书在未读徽标上叠加一个刷新小图标 | — |
| 移出书架后「点击移出」提示 | `BookInfoScreen.kt:1405-1416`、`:1425` | — | 未接 | 本地移出后无提示 | 加入书架后 1 秒内按钮显示「点击移出」，随后切「长按选分组」 | `click_to_remove` → `long_press_group` 两段提示，各 1 秒 |
| 封面无障碍描述 | `BookItem.kt:788-806` | — | 未接 | 本地封面无无障碍标签 | 读屏聚焦封面时播报书名与未读数 | `a11y_book_cover_actions` |
| 书封阴影开关 | `BookItem.kt:839`、`:965` | `components/BookCover.ets:81` | 已接 | 由 `bookshelfCoverShadow` 驱动 | 开关「书封阴影」后封面阴影出现与消失 | — |
| 网格封面宽度可调 | `BookItem.kt:839` | — | 未接 | 本地固定 compact 尺寸，无宽度设置 | 设置「网格封面宽度」为 120 后封面明显变大 | — |
| 列表封面宽度可调 | `BookItem.kt:965` | — | 未接 | 同上 | 设置「列表封面宽度」后列表封面变宽 | — |
| 未读章节数角标 | `BookItem.kt:751-752`、`:792`、`BookShelfItem.kt:50` | — | 未接 | 本地 `unread` 全仓 0 命中 | 卡片封面角显示未读数，读完该章后数字 -1 | 算法 `max(totalChapterNum - durChapterIndex - 1, 0)` |
| 更新小红点 | `BookItem.kt:753`、`:793`、`BookShelfItem.kt:48` | — | 未接 | 本地无 `isNew` 概念 | 书有新章节时封面右下出现红点 | 需 `lastCheckCount > 0` |
| 更新中进度指示 | `BookItem.kt:782` | — | 未接 | 本地无「更新中」状态 | 刷新该书时封面出现转圈遮罩 | 锁定态不显示 |
| 书籍类型标签 | `BookItem.kt:754-765`、`:794` | — | 未接 | 本地无 `showTip` 与类型角标 | 开启「显示书籍类型」后封面左下出现「音频/漫画/本地/网络文件」 | — |
| 来源标签（搜索模式） | `BookItem.kt:766-774` | — | 未接 | 本地书架无搜索模式下的来源命中高亮 | 搜索书名时卡片左下显示命中的书源名 | 仅在 `isSearchMode` 下 |
| 自定义标签行 | `BookItem.kt:888-918` | — | 未接 | 本地卡片只渲染封面与书名 | 给书打「科幻」标签后卡片显示该标签 | `bookshelfShowTag` 控制 |
| 标签按 `customTagColors` 取色 | `BookItem.kt:888-918` | — | 未接 | 本地无自定义标签配色体系 | 为「科幻」配色后卡片标签显示该颜色 | 与 A2 标签内容设置联动 |
| 列表模式简介 | `BookItem.kt:919-941` | — | 未接 | 本地卡片无简介 | 列表模式且开启「显示简介」后卡片显示简介文本 | 需 Jsoup 等价富文本处理 |
| 简介排版在书名下方 | `BookItem.kt:919-941` | — | 未接 | 同上 | 开启「简介在书名下方」后排版位置改变 | `bookshelfListIntroBelowContent` |
| 最后更新时间 | `BookItem.kt:944-951` | — | 未接 | 本地卡片无更新时间 | 开启「显示最后更新时间」后卡片显示「3 天前」 | 本地书不显示 |
| 最新章节 | `BookItem.kt:952-959` | — | 未接 | 本地卡片无最新章节 | 开启「显示最新章节」后卡片显示章名 | — |
| 字数统计 | `BookshelfConfigSheet.kt:511` 二级面板 | — | 未接 | 本地无字数计算 | 开启「显示字数」后卡片显示「12.3 万字」 | — |
| 等待更新数 | `BookshelfConfigSheet.kt:579` | — | 未接 | 本地无等待更新概念 | 开启后卡片显示等待更新的章节数 | — |
| 书名居中（网格） | `BookItem.kt:110-146` | `pages/BookshelfPage.ets:664-666` | 未接 | 本地固定左对齐 | 开启「标题居中」后网格书名居中 | `bookshelfTitleCenter` |
| 书名最大行数 | `BookItem.kt:110-146` | `pages/BookshelfPage.ets:665` | 已接 | 由 `bookshelfTitleMaxLines` 驱动 | 设为 1 行后长书名以省略号截断 | — |
| 书名小字号 | `BookItem.kt:110-146` | — | 未接 | 本地固定 13fp | 开启「标题小字号」后书名变小 | `bookshelfTitleSmallFont` |
| 列表分割线 | `BookItem.kt:253-259` | — | 未接 | 本地无列表模式 | 列表模式相邻书之间有分割线 | 本地无列表卡片实现 |
| 列表卡片背景色（日/夜） | `BookItem.kt:175-186` | — | 未接 | 本地无日/夜卡片配色 | 设日间卡片色为米色后列表卡片变色 | 同上 |
| 列表封面垂直居中 | `BookItem.kt:175-186` | — | 未接 | 本地无列表模式 | 开关后列表封面在行内垂直居中 | 同上 |
| 紧凑模式 | `BookshelfConfigSheet.kt:389` | — | 未接 | 本地无紧凑模式 | 开启后卡片高度压缩、隐藏次要信息 | `bookshelfLayoutCompact` |
| 拖拽重排书架 | `BookshelfScreen.kt:1743-1748`、`:1795-1800` | — | 未接 | 本地网格无 `ReorderableItem` 等价物 | 长按卡片可拖动换位，松手后顺序持久化 | 分组内已有拖拽（见 A3） |
| 快速滚动条 | `BookshelfScreen.kt:1770` | — | 未接 | 本地 `scrollBar(BarState.Off)` | 开启后书架右侧出现快速滚动条，可拖动定位 | `showBookshelfFastScroller` |
| 点击卡片开书 | `BookshelfScreen.kt:1808-1830` | `pages/BookshelfPage.ets:668-674` | 已接 | 缺正文时改跳详情页 | 点卡片进入阅读页并定位到上次章节 | — |
| 长按卡片进详情 | `BookshelfScreen.kt:1808-1830` | `pages/BookshelfPage.ets:675-677` | 已接 | 本地 500ms | 长按卡片弹出书籍详情页 | — |
| 选择模式工具条 | `BookshelfScreen.kt:610-681` | — | 未接 | 本地无选择模式，工具条整组缺失 | 进入选择模式后顶部出现工具条 | 本块后七条均属此组 |
| 全选 | `BookshelfScreen.kt:614` | — | 未接 | 同上 | 点「全选」后所有卡片被勾选 | — |
| 反选 | `BookshelfScreen.kt:621` | — | 未接 | 同上 | 点「反选」后勾选状态反转 | — |
| 批量下载 | `BookshelfScreen.kt:632` | — | 未接 | 同上 | 选中 3 本点下载，三本依次缓存全部章节 | — |
| 移动到分组 | `BookshelfScreen.kt:643` | — | 未接 | 同上 | 选中书籍后移动到「科幻」，该书出现在该分组 | — |
| 批量私密标记 | `BookshelfScreen.kt:655-668` | — | 未接 | 同上，且本地无私密体系 | 选中书籍标记私密后封面模糊 | 仅设密码后显示该按钮 |
| 批量删除 | `BookshelfScreen.kt:679` | — | 未接 | 本地只能在详情页单本移出 | 选中 3 本删除后书架少 3 本 | — |
| 删除时勾选删除源文件 | `BookshelfScreen.kt:1540-1572`、`:1552-1563` | — | 未接 | 本地无删除确认对话框 | 勾选后删除同时移除本地文件 | 仅 `hasLocalBook` 时显示 |
| 私密分组锁定页 | `BookshelfScreen.kt:1619-1646` | — | 未接 | 本地 `isPrivate` 只存字段，UI 无锁定态 | 进入私密分组先显示锁页 | — |
| 私密解锁（密码 + 生物识别） | `BookshelfScreen.kt:1435-1458`、`:261` | — | 未接 | 本地无密码与生物识别 | 输密码或指纹后进入私密分组 | — |
| 空态文案与表情切换 | `BookshelfScreen.kt:1647` | `pages/BookshelfPage.ets:691-702` | 已接 | 本地 7 个表情轮换，三种文案 | 清空书架后显示表情与提示，点表情可切换 | 上游为单张插图 |
| 搜索无结果空态与「全局搜索」按钮 | `BookshelfScreen.kt:1675-1683` | `pages/BookshelfPage.ets:699-701` | 未接 | 本地只把文案换成「没有匹配的书籍」，无跳全局搜索的按钮 | 搜索无结果时显示「书架里没有，去全局搜索」，点按钮跳搜索页 | `bookshelf_empty_global_search` + `global_search` |
| 分页惰性渲染 | `BookshelfScreen.kt:1669` | — | 未接 | 本地整屏一次性渲染 | 非当前分组的书不参与渲染，滚动不掉帧 | `!isCurrentPage` 时直接 return |
| 横竖屏分别布局 | `BookshelfScreen.kt:1700-1722` | `pages/BookshelfPage.ets:395-404` | 未接 | 本地只读竖屏三键，横屏无独立设置 | 横屏后书架列数改用横屏设置值 | 上游四组键，本地两组 |
| 加载中对话框 | `BookshelfScreen.kt:1575-1602` | — | 未接 | 本地无全屏加载态 | 导入大文件时出现加载对话框并可取消 | — |

---

## A2 书架设置面板

上游主体：`ui/main/bookshelf/BookshelfConfigSheet.kt`（44 个一级控件 + 标签内容二级面板 4 项）、`domain/model/settings/BookshelfSettings.kt`（51 字段）。
本地主体：`pages/BookshelfPage.ets:503-556`（9 项）、`model/BookshelfLayout.ets`（9 字段）、`data/BookshelfLayoutRepository.ets`。

本地 `pages/BookshelfPage.ets:495-497` 自述「只迁移当前项目已有数据模型能支撑的项……留待后续轮次」。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 分组样式选择 | `BookshelfConfigSheet.kt:85` | `pages/BookshelfPage.ets:510-512` | 已接 | 本地是开关「隐藏分组页签」，只有两档，缺「文件夹」 | 开关切换后页签栏出现与消失 | 第三档见 A1 |
| 隐藏没有书籍的分组 | `BookshelfConfigSheet.kt:95` | `pages/BookshelfPage.ets:513-515` | 已接 | — | 建一个空分组，开启后页签不出现该分组 | — |
| 排序方式 | `BookshelfConfigSheet.kt:106` | `pages/BookshelfPage.ets:518-519` | 已接 | 本地 7 档，`BookshelfSort.ets:38-56` 逐档对齐上游 | 改为「按书名」后书架按拼音序 | — |
| 排序方向 | `BookshelfConfigSheet.kt:117` | `pages/BookshelfPage.ets:520-521` | 已接 | — | 切换方向后书架顺序反转 | — |
| 文件夹布局模式 | `BookshelfConfigSheet.kt:144` | — | 未接 | 本地无文件夹样式 | 切换后文件夹根视图在网格与列表间切换 | — |
| 文件夹网格列数 | `BookshelfConfigSheet.kt:165` | — | 未接 | 同上 | 改为 4 后文件夹卡片每行 4 个 | — |
| 文件夹列表列数 | `BookshelfConfigSheet.kt:187` | — | 未接 | 同上 | 改为 2 后文件夹列表每行 2 个 | — |
| 文件夹列表封面宽度 | `BookshelfConfigSheet.kt:203` | — | 未接 | 同上 | 调大后文件夹封面变宽 | — |
| 文件夹列表样式 | `BookshelfConfigSheet.kt:221` | — | 未接 | 同上，上游三选项 group/compact_list/horizontal_cover_count | 切换样式后文件夹列表排版改变 | — |
| 文件夹横向封面数 | `BookshelfConfigSheet.kt:231` | — | 未接 | 同上 | 改为 6 后每行显示 6 个封面 | — |
| 布局模式（网格/列表） | `BookshelfConfigSheet.kt:248` | `pages/BookshelfPage.ets:524-534` | 已接 | 本地仅竖屏一套 | 切换后书架在网格与列表间改变 | 横屏见 A1 |
| 网格样式 | `BookshelfConfigSheet.kt:274` | — | 未接 | 本地无网格样式变体 | 切换后网格卡片排布改变 | — |
| 网格列数 | `BookshelfConfigSheet.kt:286` | `pages/BookshelfPage.ets:535-540` | 已接 | 本地 1–6 步进器 | 改为 4 后每行 4 个封面 | — |
| 紧凑标题字体 | `BookshelfConfigSheet.kt:302` | — | 未接 | 本地固定 13fp | 开启后网格书名变小 | — |
| 标题居中 | `BookshelfConfigSheet.kt:311` | — | 未接 | 本地固定左对齐 | 开启后网格书名居中 | — |
| 网格封面宽度 | `BookshelfConfigSheet.kt:320` | — | 未接 | 本地固定尺寸 | 调大后网格封面变宽 | — |
| 显示分割线 | `BookshelfConfigSheet.kt:338` | — | 未接 | 本地无列表模式 | 列表模式出现分割线 | — |
| 日间卡片背景色 | `BookshelfConfigSheet.kt:347` | — | 未接 | 本地卡片背景固定 `#1C1D23` | 设为米色后日间卡片变色 | 需日/夜双色体系 |
| 夜间卡片背景色 | `BookshelfConfigSheet.kt:368` | — | 未接 | 同上 | 设为深灰后夜间卡片变色 | 同上 |
| 紧凑详情 | `BookshelfConfigSheet.kt:389` | — | 未接 | 本地无紧凑模式 | 开启后列表卡片信息精简 | — |
| 列表封面宽度 | `BookshelfConfigSheet.kt:400` | — | 未接 | 本地无列表模式 | 调大后列表封面变宽 | — |
| 列表列数 | `BookshelfConfigSheet.kt:410` | `pages/BookshelfPage.ets:541-545` | 已接 | 本地 1–5 步进器 | 改为 2 后列表每行 2 个 | — |
| 显示更多信息 | `BookshelfConfigSheet.kt:426` | — | 未接 | 本地无此开关 | 开启后列表卡片显示更多字段 | — |
| 封面垂直居中 | `BookshelfConfigSheet.kt:439` | — | 未接 | 本地无列表模式 | 开关后列表封面垂直居中 | — |
| 显示最新章节 | `BookshelfConfigSheet.kt:448` | — | 未接 | 本地卡片无章节信息 | 开启后卡片显示最新章节名 | 联动 A1 卡片 |
| 显示简介 | `BookshelfConfigSheet.kt:457` | — | 未接 | 本地无简介渲染 | 开启后列表卡片显示简介 | 联动 A1 卡片 |
| 简介在书名下方 | `BookshelfConfigSheet.kt:466` | — | 未接 | 同上 | 开启后简介排版位置改变 | — |
| 简介行数 | `BookshelfConfigSheet.kt:478` | — | 未接 | 同上 | 设为 2 行后简介两行截断 | — |
| 显示标签 | `BookshelfConfigSheet.kt:489` | — | 未接 | 本地无标签体系 | 开启后卡片显示自定义标签 | 联动 A1 卡片 |
| 标签显示内容 | `BookshelfConfigSheet.kt:511`、`:708` | — | 未接 | 本地无标签内容设置面板 | 勾选「字数」后标签行多一项 | 二级面板入口 |
| 自定义标签配色 | `BookshelfConfigSheet.kt:518` | — | 未接 | 本地无配色体系 | 为「科幻」选色后卡片标签变色 | — |
| 管理标签配色 | `BookshelfConfigSheet.kt:525` | — | 未接 | 同上 | 打开配色管理页可增删颜色 | — |
| 书名最大行数 | `BookshelfConfigSheet.kt:540` | `pages/BookshelfPage.ets:546-548` | 已接 | 本地 1–5 步进器 | 设为 1 后长书名单行省略 | — |
| 书封阴影 | `BookshelfConfigSheet.kt:550` | `pages/BookshelfPage.ets:551-552` | 已接 | — | 开关后封面阴影出现与消失 | — |
| 显示未读数 | `BookshelfConfigSheet.kt:561` | — | 未接 | 本地无未读概念 | 开启后卡片出现未读角标 | 联动 A1 卡片 |
| 显示更新红点 | `BookshelfConfigSheet.kt:570` | — | 未接 | 本地无更新概念 | 开启后新章节出现红点 | — |
| 显示等待更新数 | `BookshelfConfigSheet.kt:579` | — | 未接 | 同上 | 开启后卡片显示等待数 | — |
| 显示书籍计数 | `BookshelfConfigSheet.kt:588` | — | 未接 | 本地分组卡片无计数 | 开启后分组显示「N 本」 | 联动 A1 文件夹 |
| 显示最后更新时间 | `BookshelfConfigSheet.kt:597` | — | 未接 | 本地卡片无时间 | 开启后卡片显示更新时间 | — |
| 显示书籍类型 | `BookshelfConfigSheet.kt:606` | — | 未接 | 本地无类型角标 | 开启后封面左下出现类型标签 | 联动 A1 卡片 |
| 搜索优先于筛选 | `BookshelfConfigSheet.kt:617` | — | 未接 | 本地搜索框与页签并存，无优先级设置 | 开启后搜索时忽略当前分组 | `search_filter_first` |
| 快速滚动条开关 | `BookshelfConfigSheet.kt:627` | — | 未接 | 本地无快速滚动条 | 开启后书架右侧出现滚动条 | — |
| 页签栏菜单按钮 | `BookshelfConfigSheet.kt:636` | — | 未接 | 本地页签栏无右侧按钮 | 开启后页签栏右端出现图标 | — |
| 书架更新线程数 | `BookshelfConfigSheet.kt:645` | — | 未接 | 本地无批量更新线程控制 | 改为 8 后批量更新并发数变化 | `bookshelfUpdateLimit` |
| 标签内容·字数 | `BookshelfConfigSheet.kt:708` | — | 未接 | 本地无二级面板 | 勾选后标签行显示字数 | — |
| 标签内容·来源分类 | `BookshelfConfigSheet.kt:708` | — | 未接 | 同上 | 勾选后标签行显示书源分类 | — |
| 标签内容·自定义标签 | `BookshelfConfigSheet.kt:708` | — | 未接 | 同上 | 勾选后标签行显示自定义标签 | — |
| 标签内容·标签字数 | `BookshelfConfigSheet.kt:708` | — | 未接 | 同上 | 勾选后标签行显示标签内字数 | — |

---

## A3 分组管理

上游主体：`ui/main/bookshelf/GroupManageSheet.kt`（377 行）、`ui/book/group/GroupEditSheet.kt`（386 行）、`ui/main/bookshelf/autoGroup/AiAutoGroupSheet.kt`（734 行）。
本地主体：`pages/BookshelfPage.ets:219-277`（管理网格）、`:280-378`（编辑表单）、`model/BookGroup.ets`、`data/BookGroupRepository.ets`（400 行）。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 分组管理面板标题 | `GroupManageSheet.kt:131` | `pages/BookshelfPage.ets:221-225` | 已接 | 本地标题为「分组管理」+ 新建/完成 | 打开面板可见标题与新建按钮 | — |
| 新建分组 | `GroupManageSheet.kt:157` | `pages/BookshelfPage.ets:221-225` | 已接 | 本地先建空分组再编辑 | 点新建后出现空分组并进入编辑表单 | — |
| AI 自动分组 | `GroupManageSheet.kt:167`、`autoGroup/AiAutoGroupSheet.kt:734` | — | 未接 | 本地 `aiAuto`/`autoGroup` 全仓 0 命中 | 点「AI 自动分组」后对未分组书产出建议分组 | 四阶段流程，需模型接入 |
| 添加标签匹配规则 | `GroupManageSheet.kt:176`、`:266-283` | — | 未接 | 本地 `tagRule` 0 命中，无规则表 | 添加规则「科幻」后，书名含该词的书自动入组 | 依赖 `tagGroupRule.json` 读写 |
| 同步标签分组 | `GroupManageSheet.kt:185` | — | 未接 | 同上 | 点同步后按已有规则重算分组归属 | — |
| 分组卡片网格 | `GroupManageSheet.kt:207-262` | `pages/BookshelfPage.ets:243-264` | 已接 | 本地固定两列 `1fr 1fr`，上游 `Adaptive(GroupCardMinWidth)` | 打开面板看到分组卡片网格 | — |
| 分组显隐开关 | `GroupManageSheet.kt:207-262` | `pages/BookshelfPage.ets:247-251` | 已接 | 本地 Toggle 直接改 `show` | 关掉某分组后书架页签不再出现它 | — |
| 分组封面 | `GroupEditSheet.kt:154-164` | `pages/BookshelfPage.ets:291-320` | 已接 | 本地点击选图、长按清除 | 选图后分组卡片显示该封面 | — |
| 分组名称 | `GroupEditSheet.kt:168-175` | `pages/BookshelfPage.ets:322-330` | 已接 | 本地空名校验在提交时 | 改名为「科幻」后书架页签同步改名 | — |
| 分组排序方式 | `GroupEditSheet.kt:180-190` | `pages/BookshelfPage.ets:332-337` | 已接 | 本地 `BookshelfSort.ets:26` 按组覆盖全局 | 设某组为「按书名」，该组内按拼音序 | — |
| 分组下拉刷新 | `GroupEditSheet.kt:196-199` | `pages/BookshelfPage.ets:339-346` | 已接 | 本地仅存字段，注释自认「当前不控制实际更新」 | 关掉某组的下拉刷新后，该组下拉不再刷新 | 字段已接、行为未接 |
| 分组私有 | `GroupEditSheet.kt:205-215` | `pages/BookshelfPage.ets:348-355` | 已接 | 本地仅存字段，注释自认「当前不限制跨分组显示」 | 标记私密后该组内容需解锁才可见 | 字段已接、行为未接，见 A1 |
| 标签匹配规则开关 | `GroupEditSheet.kt:221-228` | — | 未接 | 本地编辑表单无此项 | 开启后出现规则输入框 | — |
| 标签匹配规则输入 | `GroupEditSheet.kt:231-240` | — | 未接 | 同上 | 输入「科幻」保存后书自动入组 | — |
| 删除分组 | `GroupManageSheet.kt:134-148` | `pages/BookshelfPage.ets:357-382` | 已接 | 本地二次确认（点两次），上游为独立确认面板 | 点删除两次后分组消失，书回到未分组 | — |
| 删除分组时书籍去向提示 | `GroupManageSheet.kt:134-148` | — | 未接 | 本地删除无「N 本书将移出该分组」提示 | 删除含 3 本书的分组前提示影响数量 | — |
| 重置分组封面 | `GroupManageSheet.kt:197` | `pages/BookshelfPage.ets:310-317` | 已接 | 本地为「清除」按钮 | 点清除后分组封面恢复默认 | — |
| 分组拖拽排序 | `GroupManageSheet.kt:207-262` | `pages/BookshelfPage.ets:265-272` | 已接 | 本地 `onMove` 重排后整体写回 | 拖动分组卡片换位后书架页签顺序同步 | — |
| 分组书籍计数 | `GroupManageSheet.kt:207-262` | — | 未接 | 本地卡片副标题只有排序方式等文字 | 分组卡片显示「12 本」 | — |
| 分组四宫格预览 | `BookItem.kt:361-432` | — | 未接 | 本地卡片只显示单封面 | 分组卡片显示前 4 本书封面拼图 | 与 A1 文件夹同一组件 |
| 分组私密锁定显示 | `BookshelfScreen.kt:1619-1646` | — | 未接 | 本地无锁定态 | 私密分组卡片显示锁图标而非封面 | — |
| 分组内书籍排序覆盖 | `BookshelfRepository.kt` sortBooks | `data/BookshelfSort.ets:26` | 已接 | 分组 `bookSort >= 0` 覆盖全局 | 全局按时间、某组按书名，进该组顺序不同 | 逻辑完整对齐 |

---

## B 书籍详情页与元数据

上游主体：`ui/book/info/BookInfoScreen.kt`（2479 行）、`BookInfoViewModel.kt`（2164 行）、`BookInfoContract.kt:376-396`（20 项 `BookInfoMenuAction`）、`edit/BookInfoEditScreen.kt`（578 行）、`domain/model/Book.kt`（30 个持久字段）。
本地主体：`pages/BookInfoPage.ets`（430 行）、`model/Book.ets`（33 字段）。

本地 `model/Book.ets` 缺 `isPrivate`、`canUpdate`、`disableReadRecord`、`splitLongChapter`、`deleteAlert`、`totalChapterNum`、`latestChapterTitle`，这七项是本块多条「未接」的直接原因。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 顶栏返回 | `BookInfoScreen.kt:737` | `pages/BookInfoPage.ets:262-267` | 已接 | — | 点返回回到书架并保持原分组 | — |
| 顶栏编辑 | `BookInfoScreen.kt:877` | `pages/BookInfoPage.ets:268` | 已接 | — | 点编辑弹出元数据编辑面板 | — |
| 顶栏分享 | `BookInfoContract.kt:376-396` | `pages/BookInfoPage.ets:269` | 未接 | 本地 `onUnavailableAction('书籍分享尚未迁移')` | 点分享生成可分享的书籍卡片或链接 | — |
| 顶栏更多菜单（18 项） | `BookInfoScreen.kt:1033-1141` | `pages/BookInfoPage.ets:270` | 未接 | 本地整组占位 | 点更多弹出 18 项菜单 | 本块后续逐项列出 |
| 菜单·书源自定义按钮 | `BookInfoContract.kt:376-396` | — | 不适用 | 依赖书源自定义按钮体系，属书源模块范围，见 [项目队列](../PROJECT.md) | — | 不在本轮范围 |
| 菜单·编辑 | `BookInfoContract.kt:376-396` | `pages/BookInfoPage.ets:268` | 已接 | 与顶栏编辑同一入口 | 点菜单「编辑」弹出编辑面板 | — |
| 菜单·分享 | `BookInfoContract.kt:376-396` | — | 未接 | 同顶栏分享 | 点菜单「分享」可分享 | — |
| 菜单·上传书籍 | `BookInfoContract.kt:376-396` | — | 未接 | 本地无 WebDAV 上传 | 点上传后书籍备份到远端 | 依赖 WebDAV |
| 菜单·同步到远端 | `BookInfoContract.kt:376-396` | — | 未接 | 同上 | 点同步后远端记录更新 | 同上 |
| 菜单·刷新书籍信息 | `BookInfoContract.kt:376-396` | — | 未接 | 本地无刷新动作 | 点刷新后简介与目录更新 | — |
| 菜单·阅读记录 | `BookInfoContract.kt:376-396` | `pages/BookInfoPage.ets:197` | 已接 | 本地走动作卡而非菜单 | 点「阅读记录」打开该书阅读记录 | — |
| 菜单·禁用阅读记录 | `BookInfoContract.kt:376-396` | — | 未接 | `Book.ets` 缺 `disableReadRecord` 字段 | 禁用后读该书不再计入阅读记录 | — |
| 菜单·登录书源 | `BookInfoContract.kt:376-396` | — | 未接 | 本地无书源登录体系 | 点登录后书源账号状态变为已登录 | — |
| 菜单·置顶 | `BookInfoContract.kt:376-396` | — | 未接 | 本地无置顶动作 | 置顶后该书排在书架首位 | 依赖 `Book.order` 与置顶位 |
| 菜单·设置书源变量 | `BookInfoContract.kt:376-396` | — | 未接 | 本地无书源变量 | 修改变量后书籍内容按新变量刷新 | — |
| 菜单·设置书籍变量 | `BookInfoContract.kt:376-396` | — | 未接 | 同上 | 设置变量后该书单独生效 | — |
| 菜单·复制书籍链接 | `BookInfoContract.kt:376-396` | — | 未接 | 本地无剪贴板动作 | 复制后可粘贴出 `bookUrl` | — |
| 菜单·复制目录链接 | `BookInfoContract.kt:376-396` | — | 未接 | 同上 | 复制后可粘贴出 `tocUrl` | — |
| 菜单·允许更新 | `BookInfoContract.kt:376-396` | — | 未接 | `Book.ets` 缺 `canUpdate` 字段 | 关掉后批量更新跳过该书 | — |
| 菜单·长按分章 | `BookInfoContract.kt:376-396` | — | 未接 | `splitLongChapter` 全仓 0 命中 | 关掉后超长章节不再自动分章 | 字段在 `ReadConfig` 内嵌 |
| 菜单·删除确认 | `BookInfoContract.kt:376-396` | — | 未接 | `deleteAlert` 全仓 0 命中 | 关掉后移出书架不再弹确认 | — |
| 菜单·清除缓存 | `BookInfoContract.kt:376-396` | — | 未接 | 本地无章节缓存体系 | 点清除后缓存章节数归零 | — |
| 菜单·显示日志 | `BookInfoContract.kt:376-396` | — | 未接 | 本地无日志页 | 打开该书相关日志 | — |
| 菜单·设为私密 | `BookInfoContract.kt:376-396` | — | 未接 | `Book.ets` 缺 `isPrivate` 字段 | 标记后封面在书架模糊 | 与 A1 私密体系同一缺口 |
| 头部封面 | `BookInfoScreen.kt:1144` | `pages/BookInfoPage.ets:158-164` | 已接 | 本地 112×157 | 详情页顶部显示大封面 | — |
| 头部书名（含长按菜单） | `BookInfoScreen.kt:1298-1320` | `pages/BookInfoPage.ets:160-161` | 未接 | 本地为纯 `Text`，不可点、无长按菜单 | 长按书名弹出「搜索 / 展开」，选展开后书名不再截断 | `AnimatedTextLine` + `RoundDropdownMenu` |
| 头部作者行（点击 / 长按） | `BookInfoScreen.kt:1326` | `pages/BookInfoPage.ets:162-163` | 未接 | 本地为纯 `Text`，无点击与长按 | 点作者跳作者搜索结果，长按走另一分支 | `author_show` + `AuthorClick(longClick)` |
| 头部来源行 | `BookInfoScreen.kt:1335-1339` | — | 未接 | 本地无来源行 | 书名下显示书源名，点击进入该来源详情 | `origin_show` + `OriginClick` |
| 头部高亮标签行 | `BookInfoScreen.kt:1355-1385` | — | 未接 | 本地无高亮标签体系 | 命中高亮规则的标签以高亮样式单独一行 | `highlightedTags` ← `highlightTagRuleRepository` |
| 头部分组与类型标签横排 | `BookInfoScreen.kt:1367-1390` | `pages/BookInfoPage.ets:170-183` | 已接 | 本地把分类、分组、格式、文件大小、自定义标签合成一行 `BookInfoTag` | 详情页头部显示「分组：科幻」等标签 | 本地无 `fadingEdge` 渐隐 |
| 封面点击与长按 | `BookInfoScreen.kt:1144` | `pages/BookInfoPage.ets:158` | 未接 | 本地封面不可点 | 点封面全屏预览，长按弹出换封面 | `CoverClick`/`CoverLongClick` |
| 封面无障碍描述 | `BookInfoScreen.kt:1164` | — | 未接 | 本地无 | 读屏聚焦封面时播报书名 | `a11y_book_cover_actions` |
| 加入书架（含冲突提示） | `BookInfoScreen.kt:1390-1485` | — | 未接 | 本地入口只在书架内，无「加入」动作与同名冲突高亮 | 从搜索进详情可加入书架，同名时高亮冲突 | 本地无搜索进详情的路径 |
| 移出书架 | `BookInfoScreen.kt:1390-1485` | `pages/BookInfoPage.ets:190-194` | 已接 | 本地按钮文案「已在书架」，点击即移出并二次确认 | 点后该书从书架消失 | 文案与行为不符，见下方小结 |
| 长按加入书架选分组 | `BookInfoScreen.kt:1390-1485` | — | 未接 | 本地无此手势 | 长按「加入书架」弹出分组多选 | — |
| 动作卡·查看目录 | `BookInfoScreen.kt:1390-1485` | `pages/BookInfoPage.ets:195` | 已接 | — | 点后打开目录页并定位当前章 | — |
| 动作卡·换源 | `BookInfoScreen.kt:1390-1485`、`BookInfoViewModel.kt:1197` | `pages/BookInfoPage.ets:196` | 未接 | 本地 `onUnavailableAction('在线换源将在 P5 接入')` | 点换源后可从其它书源打开同书 | 依赖书源体系 |
| 动作卡·阅读记录入口 | `BookInfoScreen.kt:1390-1485` | `pages/BookInfoPage.ets:197` | 已接 | 本地入口在，但点开跳**全局**阅读记录页 | 点后打开阅读记录 | 面板本身见下一行 |
| 详情页内嵌本书阅读记录面板 | `BookInfoReadRecordSheet.kt:41-116` | — | 未接 | 上游是本书专属的 `GlassCard` 总时长 + 按天分组时间线面板；本地直接跳全局页，看不到本书聚合 | 点阅读记录弹出面板，顶部显示本书总时长，下面按天列出会话 | 本地 `Index.ets:3709`、`:3755` 走 `ProfileRoute.READ_RECORDS` |
| 摘要·当前章 | `BookInfoScreen.kt:1533-1625` | `pages/BookInfoPage.ets:201-202` | 已接 | 本地为「在读 · 章名」，未开始显示「尚未开始阅读」 | 读第 3 章后显示该章名 | — |
| 摘要·最新章节 | `BookInfoScreen.kt:1533-1625` | `pages/BookInfoPage.ets:204-205` | 已接 | — | 显示最后一章章名 | — |
| 摘要·总章数 | `BookInfoScreen.kt:1533-1625` | `pages/BookInfoPage.ets:206` | 已接 | 目录未读到时显示「章节总数待读取」 | 目录加载后显示「共 128 章」 | — |
| 摘要·已读状态三分支 | `BookInfoScreen.kt:1533-1625` | `pages/BookInfoPage.ets:209` | 未接 | 本地只有「已读 N 章 / 未读」两分支，缺上游「已读完」第三分支 | 读到最后一章后显示「已读完」而非「已读 128 章」 | 上游判定 `durChapterIndex + 1 == totalChapterNum` |
| 摘要·目录加载失败提示 | `BookInfoScreen.kt:1533-1625` | — | 未接 | 本地无 `error_load_toc` 等价提示 | 目录加载失败时摘要区出现「目录加载失败」 | — |
| 摘要·备注卡片可点编辑 | `BookInfoScreen.kt:1533-1625` | `pages/BookInfoPage.ets:248-251` | 未接 | 本地备注只读，编辑需进元数据面板 | 点备注卡片直接进入备注编辑 | — |
| 简介·纯文本 | `BookInfoScreen.kt:1634-1710` | `pages/BookInfoPage.ets:235-244` | 已接 | 本地只做纯文本渲染 | 简介正常显示且长文可滚动 | — |
| 简介·HTML 渲染 | `BookInfoScreen.kt:1634-1710` | — | 未接 | 本地无 `<usehtml>` 分支 | 简介含 HTML 时按富文本渲染 | — |
| 简介·Web 渲染 | `BookInfoScreen.kt:1753`、`:1842-2040` | — | 未接 | 本地无 `<useweb>` 分支与 WebView 桥 | 简介含 `<useweb>` 时用 WebView 渲染并支持跳转 | 依赖 ArkWeb |
| 简介·Markdown 渲染 | `BookInfoScreen.kt:1634-1710` | — | 未接 | 本地无 `<md>` 分支 | 简介含 Markdown 时按样式渲染 | — |
| 角色卡 | `BookInfoScreen.kt:2170`、`:2240` | — | 未接 | 本地无角色体系 | 简介下方出现角色列表 | — |
| 角色关系网 | `BookInfoScreen.kt:2240` | — | 未接 | 同上 | 角色之间显示关系连线 | — |
| 知识卡 | `BookInfoScreen.kt:2324`、`:2373` | — | 未接 | 本地无知识条目体系 | 显示知识条目卡片 | — |
| 事件卡 | `BookInfoScreen.kt:2401`、`:2453` | — | 未接 | 本地无事件体系 | 显示剧情事件时间线 | — |
| 相关书籍横幅 | `BookInfoScreen.kt:2124` | — | 未接 | 本地无相关书籍推荐 | 详情页底部出现相关书籍横排 | — |
| 私密锁定内容页 | `BookInfoScreen.kt:664` | — | 未接 | 本地无锁定态 | 私密书详情页默认显示锁定内容 | — |
| 编辑·书名 | `edit/BookInfoEditScreen.kt:238` | `pages/BookInfoPage.ets:349-352` | 已接 | — | 改名保存后书架同步 | — |
| 编辑·作者 | `edit/BookInfoEditScreen.kt:246` | `pages/BookInfoPage.ets:353-356` | 已接 | — | 改作者保存后详情页同步 | — |
| 编辑·分类 | `edit/BookInfoEditScreen.kt:262` | `pages/BookInfoPage.ets:357-360` | 已接 | — | 改分类保存后持久化 | — |
| 编辑·封面 | `edit/BookInfoEditScreen.kt:254`、`:197-207` | `pages/BookInfoPage.ets:299-310` | 已接 | 本地为选本地图片，非填封面 URL | 选图后封面更新，还原后恢复 | 方式不同 |
| 编辑·简介 | `edit/BookInfoEditScreen.kt:278` | `pages/BookInfoPage.ets:365-368` | 已接 | — | 改简介保存后详情页同步 | — |
| 编辑·备注 | `edit/BookInfoEditScreen.kt:286` | `pages/BookInfoPage.ets:369-372` | 已接 | — | 加备注保存后详情页显示 | — |
| 编辑·标签编辑器 | `edit/BookInfoEditScreen.kt:435-517` | `pages/BookInfoPage.ets:361-364` | 未接 | 本地是逗号分隔单行输入，无增删改标签的编辑器 | 可逐个添加、编辑、删除标签 | 上游有 `add_tag`/`edit_tag`/`reset` |
| 编辑·书籍类型 | `edit/BookInfoEditScreen.kt:213-215` | `pages/BookInfoPage.ets:314-318` | 已接 | 本地三选：文本/音频/图片 | 切换类型后卡片角标随之改变 | — |
| 编辑·固定书籍类型 | `edit/BookInfoEditScreen.kt:231` | `pages/BookInfoPage.ets:319-323` | 已接 | — | 开启后刷新信息不再改类型 | — |
| 编辑·知识卡编辑 | `edit/BookInfoEditScreen.kt:310-343` | — | 未接 | 本地编辑面板无角色/知识/事件 | 可在编辑面板增删角色与事件 | — |
| 编辑·空名校验 | `edit/BookInfoEditScreen.kt:245-250` | `pages/BookInfoPage.ets:116` | 已接 | 本地空名时提示并阻止保存 | 清空书名点保存被拒绝并提示 | — |
| 书架删除面板 | `ShelfDeleteSheet.kt`（182 行） | `pages/BookInfoPage.ets:85` | 未接 | 本地只弹系统确认框，无「同时删除文件」等选项 | 移出时可选是否删除本地文件与阅读记录 | — |
| 书架删除面板·同名副本切换 | `ShelfDeleteSheet.kt:102-128` | — | 未接 | 本地无同名副本概念 | 面板列出同名同作者的其他副本，可点开查看 | `shelf_delete_view_copy` |
| 书架删除面板·删除源文件勾选 | `ShelfDeleteSheet.kt:167-168` | — | 未接 | 本地无此勾选 | 勾选后移出同时删除本地文件 | `delete_book_file` |
| 面板·分组多选 | `BookInfoSheets.kt:109` | `pages/BookInfoPage.ets:327-340` | 未接 | 上游为独立面板（标题 + 新建分组 + 逐行编辑 + 位掩码选择）；本地把多选塞在元数据编辑面板内 | 点分组标签弹出多选面板，可在面板内新建分组 | `GroupSelectSheet`，`groupId` 位掩码 |
| 面板·在线换封面 | `BookInfoSheets.kt:194` | — | 未接 | 本地只能从相册选图或还原，无在线搜封面 | 点换封面后按书源搜索封面，三列网格可选 | `ChangeCoverSheet`，带搜索/停止切换 |
| 面板·网络文件选择 | `BookInfoSheets.kt:70` | — | 未接 | 本地无网络文件导入 | 导入网文链接时列出可选文件，压缩包显示文件夹图标 | `WebFileSheet` |
| 面板·压缩包条目选择 | `BookInfoContract.kt` `ArchiveEntries` | — | 未接 | 本地无压缩包导入 | 选 zip 后列出内部条目可选其一 | — |
| 面板·不支持文件提示 | `BookInfoContract.kt` `UnsupportedWebFile` | — | 未接 | 本地无 | 选中不支持的格式时弹提示 | `file_not_supported` |
| 书源回调按钮 | `BookInfoViewModel.kt:265-311` | — | 未接 | 本地无书源回调体系 | 书源定义的按钮出现在详情页，点后按类型搜索/分享/复制/清缓存 | `BookInfoCallbackAction` 四值 |
| 简介 JS 执行 | `BookInfoViewModel.kt:318-335` | — | 未接 | 本地无简介脚本 | 简介里的脚本按钮点击后执行并回写结果 | 注入 `result`/`java`/`book` |
| 简介内按钮点击 | `BookInfoContract.kt` `IntroButtonClick` | — | 未接 | 本地无 `<button>` 解析 | 简介含按钮时点击触发脚本 | 格式 `<button>名@onclick:脚本</button>` |
| 简介图片点击与长按 | `BookInfoContract.kt` `IntroImageClick`/`IntroImageLongClick` | — | 未接 | 本地无简介图片交互 | 点简介图片执行脚本，长按走另一分支 | — |
| 作者其他作品 | `BookInfoViewModel.kt:2069` | — | 未接 | 本地无 | 点作者后列出该作者其他书 | `book_other_works` |
| 目录选择（book tree uri） | `BookInfoScreen.kt:243` | — | 未接 | 本地无 SAF 目录授权 | 选目录后可作为书籍根目录 | `SetDefaultBookTreeUri` |

---

## C 阅读进度与记录

上游主体：`ui/book/readRecord/ReadRecordScreen.kt`（1663 行）、`ReadRecordViewModel.kt`（385 行）、`ReadRecordCharts.kt`（181 行）、`ReadRecordStats.kt`（109 行）、`ReadRecordOverviewScreen.kt`（547 行）。
本地主体：`pages/ProfileSubPages.ets:2907` 起（`ReadRecordsPage`）、`data/ReadRecordRepository.ets`、`model/ReadRecord.ets`。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 阅读进度写入 | `Book.kt:45-138` | `model/Book.ets` | 已接 | 本地 `chapterIndex`/`chapterProgress`/`durChapterTime` | 读 3 章后退出，书架排序按最后阅读更新 | — |
| 进度恢复（打开即定位） | `ReadBookConfig.kt` | `pages/ReaderPage.ets` | 已接 | — | 关掉 App 重开，点该书回到上次章节与位置 | — |
| 章节内位置记忆 | `Book.kt:45-138` | `model/Book.ets` | 已接 | 本地 `chapterProgress` + `readerPositionVersion` | 在同一章内滚动后退出再进，停在原位 | 见 `androidCharacterPosition` 兼容 |
| 阅读记录开关 | `ReadRecordScreen.kt:703` | `pages/ProfileSubPages.ets:3088-3096` | 已接 | — | 关掉后读书不再产生记录 | — |
| 阅读记录三视图切换 | `ReadRecordScreen.kt:939` | `pages/ProfileSubPages.ets:2935` | 已接 | 本地 `cycleDisplayMode()` 轮换 0 汇总/1 时间线/2 最后阅读 | 点视图图标在三种视图间轮换 | 上游为图标按钮组 |
| 阅读记录搜索 | `ReadRecordScreen.kt` | `pages/ProfileSubPages.ets:2940` | 已接 | 本地按书名与作者过滤 | 输入书名后列表只剩该书记录 | — |
| 汇总视图 | `ReadRecordScreen.kt:813` | `pages/ProfileSubPages.ets:3213` | 已接 | 本地按日期分组、按书聚合时长 | 汇总视图按日期显示各书阅读时长 | — |
| 时间线视图 | `ReadRecordScreen.kt:939`、`:1254` | `pages/ProfileSubPages.ets:3236` | 已接 | — | 时间线按会话列出开始时间与时长 | — |
| 最后阅读视图 | `ReadRecordScreen.kt:1143` | `pages/ProfileSubPages.ets:3258` | 已接 | — | 列表按最后阅读时间倒序 | — |
| 阅读总成就 | `ReadRecordScreen.kt` | `pages/ProfileSubPages.ets:3202-3211` | 已接 | 本地显示本书数与总时长 | 顶部卡片显示「N 本书 · X 小时」 | — |
| 热力图日历 | `ReadRecordScreen.kt:860` | — | 未接 | 本地无热力图，点击成就卡只开空 sheet | 显示近一年的阅读热力格子 | `HeatmapCalendarSection` |
| 阅读时长柱状图 | `ReadRecordCharts.kt:40` | — | 未接 | 本地无图表 | 显示近 7 天阅读时长柱状图 | — |
| 统计格子 | `ReadRecordStats.kt:35`、`:79` | — | 未接 | 本地无统计格 | 显示日均时长、最长单次等指标 | — |
| 扫描问题 | `ReadRecordScreen.kt:703` | `pages/ProfileSubPages.ets:3098-3108` | 已接 | 本地扫描只读，不改数据 | 点扫描后列出异常记录条数 | — |
| 修复记录 | `ReadRecordScreen.kt:703` | `pages/ProfileSubPages.ets:3110-3120` | 已接 | 本地 `ReadRecordRepository.repair` | 点修复后异常记录数归零 | — |
| 清空阅读记录 | `ReadRecordScreen.kt:703` | `pages/ProfileSubPages.ets:3122-3135` | 已接 | — | 点清空并确认后记录数归零 | — |
| 清空二次确认 | `ReadRecordScreen.kt` `confirm_delete_read_record` | `pages/ProfileSubPages.ets:3122-3135` | 已接 | 本地单条确认文案 | 点清空弹确认框，取消则不删 | — |
| 「不再提醒」两档 | `ReadRecordScreen.kt` `do_not_remind_again_this_page`/`_long_term` | — | 未接 | 本地确认框无「不再提醒」选项 | 勾选「本页不再提醒」后下次不再弹 | 上游分本次与本机两档 |
| 合并同名书籍 | `ReadRecordScreen.kt` `merge_read_records` | — | 未接 | 本地无合并入口 | 把「同名不同作者」的两组记录合并 | — |
| 合并候选搜索 | `ReadRecordScreen.kt` `search_placeholder` | — | 未接 | 同上 | 合并时可搜索候选并提示无候选 | — |
| 选择模式批量删除 | `ReadRecordScreen.kt` `selected_count`/`delete_selected` | — | 未接 | 本地只能整体清空 | 选中 3 条记录删除后只剩其余 | — |
| 单条记录删除 | `ReadRecordScreen.kt` `del_read_record` | — | 未接 | 同上 | 长按单条记录可删除 | — |
| 阅读记录总览页 | `ReadRecordOverviewScreen.kt`（547 行） | — | 未接 | 本地无独立总览页 | 打开总览页看到跨书统计与趋势 | 下列五条是总览页内的分区 |
| 总览·统计格 | `ReadRecordOverviewScreen.kt:167-178` | — | 未接 | 本地无总览统计 | 显示阅读时长、阅读天数、总本数、读完、在读五项 | `StatsGridCard` |
| 总览·跨书热力图 | `ReadRecordOverviewScreen.kt:300-310` | — | 未接 | 本地无 | 显示全部书籍合并的年度热力图 | `HeatmapMode.TIME` |
| 总览·阅读时长排行 | `ReadRecordOverviewScreen.kt:338` | — | 未接 | 本地无 | 按阅读时长倒序列出 Top 书单，带封面 | `reading_time_ranking` |
| 总览·阅读日历（月历） | `ReadRecordOverviewScreen.kt:450` | — | 未接 | 本地无 | 显示当月日历，有阅读的日期高亮 | 可切换上/下月 |
| 总览·日历日详情 | `ReadRecordOverviewScreen.kt:510-516` | — | 未接 | 本地无 | 点日历某天显示当天读了哪些书、多久 | `a11y_reading_calendar_day_with_book` |
| 最短有效时长阈值 | `GetReadRecordOverviewUseCase.kt` | `data/ReadRecordRepository.ets` | 已接 | 本地 `minimumReadDurationMs = 10000` | 停留 5 秒退出不产生记录，15 秒产生 | — |
| 自动保存间隔 | `ReadRecordViewModel.kt` | `data/ReadRecordRepository.ets` | 已接 | 本地 `autoSaveIntervalMs = 120000` | 连续阅读 2 分钟后记录落盘 | — |
| 章节索引格式化 | `ReadRecordScreen.kt` `chapter_index_format` | — | 未接 | 本地无「第 N 章」格式化显示 | 记录条目显示「第 12 章」而非裸数字 | — |
| 详情页进度条 | `BookInfoScreen.kt:1533-1625` | `pages/BookInfoPage.ets:211-217` | 已接 | 本地按 `progress` 百分比渲染 | 读到 50% 时进度条半满 | — |

---

## 小结

**三块合计 260 条：已接 76、未接 183、不适用 1，无 `待定`。**

五处需要特别注意：

1. **两个「已接」是字段级而非行为级。** 分组的下拉刷新（`pages/BookshelfPage.ets:339-346`）与私有分组（`:348-355`）能存能读，但代码注释自己写明「当前不控制实际更新」「当前不限制跨分组显示」。行为补全牵动 A1 的私密锁定与批量刷新，不能只当字段活干。

2. **详情页第一张动作卡文案与行为不符。** 上游是「加入书架 / 已在书架」的切换（`BookInfoScreen.kt:1390-1485`），本地 `pages/BookInfoPage.ets:190-194` 文案写「已在书架」但点击直接移出，且无「加入」路径——因为本地详情页只能从书架进入。补这条要先有「从搜索/发现进详情」的入口。

3. **卡片展示是最大的单块空洞。** A1 的 63 条未接里有 22 条是卡片上的一行文字或一个角标（未读、红点、更新中、类型、来源、标签、简介、更新时间、最新章节、字数、等待更新、作者行、当前章描述、书名居中/小字号、列表分割线/背景色/封面居中/紧凑），彼此独立、风险低、可一次推进，但它们全部依赖 `model/Book.ets` 先补 `totalChapterNum`、`latestChapterTitle`、`isNew` 一类字段。

4. **「可点的文字」是二轮补漏的主线。** 详情页头部的书名、作者、来源三行在本地都是纯 `Text`，上游每行都有单击与长按两个动作（`BookInfoScreen.kt:1298-1339`）。加上封面点击/长按、分组标签点击、简介内按钮与图片点击，B 区有 12 条差异都源于「本地没有可交互元素」这一类，不是缺数据而是缺交互。

5. **结构性缺口只有两处**，其余都是可增量补的项：一是 `bookGroupStyle` 缺第三档「文件夹」（牵动 A1 五条 + A2 六条），二是私密体系（分组私有、书籍私有、解锁、锁定页，牵动 A1 三条 + A3 两条 + B 两条）。

建议顺序：先补 `model/Book.ets` 缺的七个字段 → 再落卡片展示 22 条与 A2 显示类开关 → 再补顶栏 8 条（不依赖数据，纯 UI）→ 再补 `bookGroupStyle` 第三档文件夹与分组预览计数 → 再选择模式七件套与拖拽 → 详情页头部可点元素 7 条 → 详情页菜单动作按依赖分批（不依赖书源的九个：刷新书籍信息、置顶、复制书籍链接、复制目录链接、允许更新、长按分章、删除确认、清除缓存、显示日志）→ 私密体系单独一轮 → 书源相关的换源、变量、登录、上传同步、回调按钮、简介脚本等随书源模块 → 阅读记录总览页与图表、合并同名单独一轮。

## 交叉引用

- 总账入口：[`STATUS.md`](STATUS.md) 的 `localBook` 与 `bookGroup` 行
- 备份往返口径：`data/BackupRepository.ets:315`、`:346`（`bookshelf.json`、`bookGroup.json`、`config.xml` 已具名读写，`tagGroupRule.json` 仅白名单归档）
- 阅读配置对照：[`READER-CONFIG.md`](READER-CONFIG.md)
