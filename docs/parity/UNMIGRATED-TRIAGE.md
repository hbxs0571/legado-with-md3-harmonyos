# 未接项三分类总账（155 条逐条落点）

> 本文回答用户 2026-11-20 的三问：**①除不适配外还有什么理由能不接；②缺验证的到底接没接；③未接怎么分类**。
>
> 口径：`docs/PARITY-RULES.md` 第四节四类「不适用」里，**用户把门槛收窄成只认「平台无此能力」**。因此 `范围之外`（AI 服务、额外设备形态）与 `上游无此行为` 都不再作为免做理由，一律退回 `未接`。本文按这个更严的口径重排。
>
> 数据来源：`python scripts/parity-rows.py` 七表实测 **1226 行 = 已接 1040 / 未接 155 / 不适用 31 / 待定 0**，本文只处理这 **155 条 `未接`**；31 条 `不适用` 不在本文范围。

## 一、结论先给

| 问题 | 答案 |
| --- | --- |
| 除「不适配」外，还有没有别的理由能不接？ | **没有**。原 23 条「不接」逐条复核后，**20 条判据不成立退回 `未接`**，只剩 **3 条**站得住，且都是「平台无此能力」（Monet 取色 / 双控件引擎 / intent-effect 分层）。 |
| 缺验证的那几条到底接了没？ | **12 条全部查完**。原标「代码已落地缺验证」的 10 条里：EPUB 2 条 + MOBI 2 条上机跑通判 **已接**；PDF 6 条代码全实现，但这台模拟器缺 PDFKit，只能真机验。另有 2 条（`TXT-READER.md:352` / `:436`）是表作者自记「待验收方判定」，仍缺屏幕证据。 |
| 155 条怎么分类？ | 按**卡点**分 12 类，见下表。真正属「平台无能力」的只有 **3 条**，属「要多花工但能做」的 **1 条**（rar/7z），其余 151 条都是「还没做 / 还没接线 / 缺前置」。 |

### 155 条按卡点分布

| # | 分类 | 条数 | 能不能做 |
| --- | --- | --- | --- |
| 1 | A 本轮上机验证已接 | 4 | 已接，改表即可 |
| 2 | B 不适用·平台无此能力（SDK 零命中取证） | 3 | 平台不能 |
| 3 | C 代码已落地·缺真机验证（模拟器缺 PDFKit） | 6 | 能做，需真机 |
| 4 | D 代码已落地·缺验收证据（表作者自记待判定） | 2 | 能做，需取证 |
| 5 | E 原判「不接」但判据不成立，退回未接 | 20 | 能做 |
| 6 | F 依赖在线书源/网络（引擎已落地，缺消费方接线） | 37 | 能做，引擎已在 |
| 7 | G 依赖 TTS/朗读（已纳入范围，未排期） | 7 | 能做，已纳入范围 |
| 8 | H 依赖 AI 在线服务（范围之外，按用户口径仍记未接） | 2 | 能做，卡在范围决策 |
| 9 | I 缺本地数据层/实体（表或字段没建） | 4 | 能做，先建表 |
| 10 | J 缺前置模块（排版引擎/缓存体系/编辑器） | 14 | 能做，先做前置 |
| 11 | K 依赖平台能力（须自研或引三方库） | 1 | 能做，要多花工 |
| 12 | L 纯本地功能未做（平台支持、缺入口或面板） | 55 | 能做，排期即可 |
| | **合计** | **155** | |

**所以「排除不适配后还有多少未接」的答案是 152 条**（155 − 3 条平台无能力）。若再把本轮已验通过的 4 条按 `已接` 算，则是 **148 条**。

---

## 二、逐条落点

### A 本轮上机验证已接

> **卡点**：构造样本上机跑通，结论是**已接**——这 4 条应从对照表的 `未接` 改成 `已接`（本轮未改表，只在此登记证据）。
>
> **怎么解**：证据见本文第三节。

- `TXT-READER.md:500` **正文三处净化：`<title>` 元素 / `[style*=display:none]` 块 / 重复的 cover.jpeg**（E EPUB 专属层）
  - 实测：构造样本 `净化验证.epub` 上机导入。正文 `.txt` 里 `<title>` 元素文字与 `display:none` 块文字**都不出现**；连排两张 `cover.jpeg` 只留第一张的 `[[EPUB_IMAGE:]]`，第二张被跳过。74 本真 EPUB 里没有可见对照（非封面章 body 内 `<title>` 0 本、`display:none` 块内文字全为空 2 本、重复 cover.jpeg 0 本），只能靠构造样本验。
- `TXT-READER.md:504` **SVG `<image>` 转 `<img>`（`xlink:href` 搬进 `src`）**（E EPUB 专属层）
  - 实测：同上样本第二章的 `<svg><image xlink:href="images/pic.png"/></svg>` 上机导入后，正文出现 `[[EPUB_IMAGE:file://…/1.img]]` 且图片真的落盘，正文首尾文字完整。74 本真书里有 4 章含 `<image xlink:href>`（都在 `(机翻中日对照)超かぐや姫！.epub` 的 fmatter / toc / bookwalker 页），这些页不属正文路径，所以真书里看不到差别。
- `TXT-READER.md:551` **分卷 `isVolume`（`subitems != null`）**（G MOBI · AZW3 专属层）
  - 实测：构造 `volume-probe.mobi`（自写 INDX / TAGX / IDXT / CNCX，标签 21=parent、22=firstChild 表达卷层级）上机导入后，`chapters` 表实测：`第一卷 卷首` 一行 `isVolume=1 tocLevel=0`，三个子章 `isVolume=0 tocLevel=1`。本地判据 `children !== undefined` 与上游 `ref.subitems != null` 行为一致。
- `TXT-READER.md:557` **Huff/CDIC 解压（Kindle 的 Huffman + 字典压缩）**（G MOBI · AZW3 专属层）
  - 实测：构造 `huffcdic-probe.mobi`（`compression=0x4448`，自造 HUFF 表 256 项 + 2 条 CDIC 字典项 + 对应位流）上机导入后，`books/local-f4be560e038b6b93.txt` 里 16 段探针文字**全部按位流顺序正确解出**（字典项 0/1 交替 4 次一轮、共 4 轮），无乱码无缺段。真书 4 本全是 `compression=2`，只能靠构造样本验。

### B 不适用·平台无此能力（SDK 零命中取证）

> **卡点**：SDK 里确实没有这个能力，且用零命中取到了证。这是**唯一符合用户口径**的「不适用」类型。
>
> **怎么解**：`docs/PARITY-RULES.md:85` 要求的证据形态是「SDK 声明文件路径 + 行号 + 缺失说明」，本文按此给出。

- `ZIP-THEME.md:68` **A3 Miuix 引擎下的动态取色（Monet）**（A 主题设置页）
  - 证据：`grep -rn MaterialYou|materialYou|DynamicScheme|FromWallpaper $SDK/default/openharmony/ets/api` **零命中**；`grep -rn getSystemColor|wallpaper @ohos.arkui.theme.d.ts` **零命中**；`@ohos.arkui.theme.d.ts:728` 只有 `static setDefaultTheme(theme: CustomTheme)`，**无壁纸取色入口**。
- `ZIP-THEME.md:72` **A7 主题引擎切换（Miuix / Material）**（A 主题设置页）
  - 证据：`ls $SDK` = `default`；`ls $SDK/default` = `hms` / `openharmony`；`ls $SDK/default/openharmony` = `ets js native previewer toolchains`。**只有一套 ArkUI 控件体系**，无 Miuix / Material 双引擎可切。
- `ZIP-THEME.md:180` **E7 提醒的 intent/effect 链路**（E 日夜提醒）
  - 证据：上游 `ReadBookController.kt:2563-2565` 自己注明「effect not currently emitted」；ArkUI 用 `@State` + `@Prop` 回调，**无 intent/effect 分层机制**。按用户口径只认第二条（平台无此能力），成立。E1–E6 已直接实现提醒与切换。

### C 代码已落地·缺真机验证（模拟器缺 PDFKit）

> **卡点**：代码全实现、导入链已接，但**这台模拟器没有 PDFKit**，页图渲染只能在真机验。
>
> **怎么解**：换真机跑一次 PDF 导入即可定论；模拟器侧已验「给可读提示、不崩、书架不落半截书」。

- `TXT-READER.md:526` **按页数切章：每 10 页一章，章名 `分段_N`，`url = pdf_N`**（F PDF 专属层）
  - 现状：上游不按 PDF 自带的书签切章，而是**每 10 页硬切成一段**，章名就叫「分段_1」「分段_2」，URL 是 `pdf_0` `pdf_1`。这样切的好处是不依赖 PDF 是否带目录，代价是章名对用户没有意义。本地没有这条，PDF 进不来也就没有章。 **实现情况（r344）**：代码已落地——`data/PdfRepository.ets` 的 `PAGE_SIZE = 10`、章名 `分段_${index + 1}`、`url = pdf_N`；但模拟器缺 PDFKit 能力，走不到 `loadDocum…
- `TXT-READER.md:527` **章正文 = 一串页图引用（`<img src="页号" >`）**（F PDF 专属层）
  - 现状：上游把一章的正文写成「10 个 `<img>` 引用」，页图由 `getImage(href)` 现渲。本地没有 PDF 正文形态，但**不用新造标记**：`[[EPUB_IMAGE:file://…]]` 一套标记已经能把图片塞进排版流，PDF 页图渲成文件后走同一条路即可。 **实现情况（r344）**：代码已落地——每章正文是 10 行 `[[EPUB_IMAGE:file://<filesDir>/pdf-pages/<bookId>/<页号>.img]]`，复用现有图片标记不新增语义。未在模拟器验证（缺 …
- `TXT-READER.md:528` **页图渲染：按屏幕宽度等比缩放**（F PDF 专属层）
  - 现状：上游按「屏幕宽 × 页宽高比」算渲染尺寸，白底渲染。本地要做的是「用 PDFKit 渲成 PixelMap → 存成文件 → 给 `[[EPUB_IMAGE:]]`」，渲染尺寸同理按屏宽算。**这条是整块的技术核心**：做不出来 PDF 就不能读。 **实现情况（r344）**：代码已落地——进 PDF 分支前先 `canIUse('SystemCapability.OfficeService.PDFService.Core')`，为 false 立刻抛可读错误不走到 `new PdfDocument()`；`lo…
- `TXT-READER.md:529` **封面：渲染第 0 页，JPEG 质量 90**（F PDF 专属层）
  - 现状：本地书架卡的封面落盘路径是 `${context.filesDir}/covers/<bookId>.img`（EPUB 已用），PDF 渲完第 0 页写同一个位置即可复用现有取封面逻辑。 **实现情况（r344）**：代码已落地——渲第 0 页写 `covers/<bookId>.img`，与 EPUB 封面同一落点，书架卡自动复用。未在模拟器验证（缺 PDFKit 能力，需真机）
- `TXT-READER.md:530` **书名 = 文件名去 `.pdf`；导入失败写「书籍导入异常」**（F PDF 专属层）
  - 现状：上游**不从 PDF 元数据读书名**，只用文件名；也不读作者。本地 `originName` 是 `local-<md5>.txt` 形态（`BookRepository.ets:1445`），照抄 `originName` 会得到一串 md5 —— 必须改用导入时拿到的原文件名（`importSingleUri` 里的 `fileName`）。 **实现情况（r344）**：代码已落地——书名取 `localTitleFromFileName(fileName)`，**不照抄上游 `originName.rep…
- `TXT-READER.md:531` **加密 PDF：不提示密码，直接失败**（F PDF 专属层）
  - 现状：上游没有密码位，加密 PDF 会在 `PdfRenderer` 构造时抛异常，用户看到的是导入失败。平台 `PdfDocument.loadDocument(path, password?, onProgress?)` **有密码位**（`@since 5.0.0(12)`），本地可以做得比上游好：检测到 `isEncrypted` 就弹密码框。 **实现情况（r344）**：代码已落地——`PARSE_ERROR_PASSWORD` 抛「这本 PDF 有打开密码，暂不支持」，不弹密码框，与上游同路（本地平台虽 `…

### D 代码已落地·缺验收证据（表作者自记待判定）

> **卡点**：代码已落地，但表作者自己在差异说明里写了「只交代码与截图证据、不做完成态宣告，待验收方判定」。
>
> **怎么解**：补一次屏幕取证即可定论。

- `TXT-READER.md:352` **反序在数据源层一次反转（`reverseTocHierarchy`，保父在子前）**（C5 目录页）
  - 现状：r327 已把「整个扁平数组从尾到头复制」改成按卷分组反转（卷标题仍排在子章之前），代码形态对齐上游 `TocHierarchy.kt:56-86`。但**拿不出屏幕证据**：测试书 `the-metamorphosis` 13 章全是 `第N章(1)`、没有分卷，倒序后只能看到「第13→第1」的平铺反转（`m14.jpeg` 是从第 9 章开始的滚动位置），卷标题与子章的相对位置无从观察。按「已接必须有屏幕现象」的口径，本行仍判 `未接`。
- `TXT-READER.md:436` **选区范围：滚动模式跨 current + next + nextPlus（`last = 2`）**（D4 长按选词与选区）
  - 现状：页层批次 2 已落地代码路径：选区激活时按 `pageIndex` 登记 current+next+nextPlus 三页几何，邻页也画高亮条带，`positionAtScrollWindow` 按内容坐标所在页的 extent 区间选几何命中；翻页模式仍只选当前页。状态仍记 `未接`：`已接` 须写「哪个页面/哪处现象」，本批只交代码与截图证据、不做完成态宣告，待验收方判定。

### E 原判「不接」但判据不成立，退回未接

> **卡点**：原判理由逐条复核后**全部不成立**：或是实现条件差异、或是前提已被后续批次推翻、或根本没写理由。按用户口径「除不适配外没有别的理由能不接」，这些全部退回 `未接`。
>
> **怎么解**：每条下面写了原判据与为什么推翻它。

- `BOOKSHELF.md:85` **标题加载中字符闪烁**（A1 书架主屏与卡片）
  - 重判：原判据「纯装饰动效、本地首屏无网络等待」是实现条件差异，不是平台无能力。要不要做属排期，不能记「不接」。
- `BOOKSHELF.md:113` **移出书架后「点击移出」提示**（A1 书架主屏与卡片）
  - 重判：原判据「触发条件在本地不存在」——本地详情页只能从书架进入、没有「加入书架」动作。同样是入口缺失，不是平台无能力。
- `BOOKSHELF.md:320` **角色卡**（B 书籍详情页与元数据）
  - 重判：上游角色卡数据来自 `AiToolRepository.kt:549 upsertCharacterProfile`（AI 工具写入 `BookCharacterProfile`）。本地平台**不缺显示角色列表的能力**，缺的是数据来源。
- `BOOKSHELF.md:321` **角色关系网**（B 书籍详情页与元数据）
  - 重判：关系网同理：上游 `getCharacterRelations` 读 `BookCharacterRelation` 表，写入方是 AI 工具。
- `BOOKSHELF.md:322` **知识卡**（B 书籍详情页与元数据）
  - 重判：知识卡同理：`BookKnowledgeEntry` 由 AI 工具写入。本地 `BookInfoEditPage.ets:217-247` 已把「知识」卡四个描边按钮（人物 / 关系网 / 世界知识 / 事件列表）画出来，点了提示未接入——**入口已在、缺数据源**。
- `BOOKSHELF.md:323` **事件卡**（B 书籍详情页与元数据）
  - 重判：事件卡同理：`BookCharacterEvent` 由 AI 工具写入。
- `BOOKSHELF.md:335` **编辑·知识卡编辑**（B 书籍详情页与元数据）
  - 重判：知识卡编辑面板同理：依赖 `BookKnowledgeEntry` 实体，本地没有该表，属数据层未建。
- `BOOKSHELF.md:455` **下载全部**（D3 书架管理页）
  - 重判：原判据「readBookRow 把 isLocal 写死 true」**已被 P3-E 推翻**：`BookRepository.ets:1074-1078` 改按 `origin === loc_book` 派生、`:1145` 回填；`OnlineBookService`（`bookSource/OnlineBookService.ets`）已实现在线书章节缓存（`online_book_cache/`、`%05d-<md5>.nb`）。在线书能进书架，下载语义成立。
- `BOOKSHELF.md:457` **日志**（D3 书架管理页）
  - 重判：原判据自认「能力已在（AppLog 加书架页日志面板），本页不重复放同源入口」——能力在、只是入口位置不同，属形态差异。
- `BOOKSHELF.md:459` **行内下载/停止**（D3 书架管理页）
  - 重判：同 `:455`，前提失效。
- `BOOKSHELF.md:466` **选择模式·批量下载**（D3 书架管理页）
  - 重判：同 `:455`，前提失效。
- `BOOKSHELF.md:469` **选择模式·清除缓存**（D3 书架管理页）
  - 重判：原判据「本地唯一能删的是 contentPath，删了书就变缺正文」——本地存储形态带来的语义差别，不是平台无此能力。
- `BOOKSHELF.md:471` **选择模式·分段导出**（D3 书架管理页）
  - 重判：原判据「本地书一本一个 TXT，整本导出已覆盖」——章节有 `start`/`end` 偏移，按范围切片技术上完全可做，是场景判断不是能力判断。
- `BOOKSHELF.md:507` **WebDAV 账号密码对话框**（E 备份恢复）
  - 重判：原判据自认「与上游单对话框两字段等效，只差形态」——写了「等效」就不能记不接。
- `BOOKSHELF.md:522` **该类的恢复落地方式：恢复时按条目名具名分支，落到原生仓储**（E 备份恢复）
  - 重判：原判据「本地无 keyboardAssists 表，走 backup-entries 兜底」——本地缺表属「还没做」。
- `BOOKSHELF.md:523` **该类的备份写出方式：从数据库取全表，序列化为 JSON 落 ZIP**（E 备份恢复）
  - 重判：同 `:522`，本地无该表数据源 = 还没做。
- `ZIP-BOOKSHELF-LAYOUT.md:124` **分组封面阴影**（B 卡片渲染）
  - 重判：原备注只有「**不接**」两个字，**一条依据都没写**。按 `docs/PARITY-RULES.md:89`「一条都写不出，就不能判不适用——降级为未接」，这里连 `不适用` 都没资格。
- `ZIP-THEME.md:83` **A18 平板界面**（A 主题设置页）
  - 重判：原判据引 `PROJECT.md:48-50`「额外设备形态适配属范围之外」。但 SDK 有 `tablet.json` / `2in1.json` device-define，平台**支持平板**——范围之外是产品决策不是平台限制。
- `ZIP-THEME.md:84` **A19 多窗布局**（A 主题设置页）
  - 重判：同 `:83`。多窗布局在 HarmonyOS 有 `WindowStage` 与 `multiWindow` 能力，不是平台缺失。
- `ZIP-THEME.md:88` **A23 作者搜索回退**（A 主题设置页）
  - 重判：原判据「在线书源与 relatedBooks 规则在本平台不存在」——书源 P1–P11 已落地（`bookSource/` 目录、`model/BookSource.ets`、`BookSourceEditPage.ets:76` 的 `ruleBookInfo.relatedBooks` 编辑项、`ThemeSettingsPage.ets:759` 的开关与文案）。开关本身也已落地（`ThemeSettingsRepository.ets:67/272/331/392/511`、备份键 `BackupRepository.ets:542`、`Index.ets:661/662/3643/3766`）。缺的只是最后的消费者。

### F 依赖在线书源/网络（引擎已落地，缺消费方接线）

> **卡点**：这类**不是「不能做」，是「消费者还没接」**。书源引擎 P1–P11 已落地（`bookSource/` 目录、`model/BookSource.ets`、`BookSourceRuntime`、`OnlineBookService`），缺的是界面与业务侧把结果用起来。
>
> **怎么解**：随书源界面批一起接。

- `BOOKSHELF.md:89` **更多菜单·远程书籍**（A1 书架主屏与卡片）
  - 现状：本地 `onUnavailableAction('远程书籍导入尚未迁移')`
- `BOOKSHELF.md:94` **更多菜单·添加网址**（A1 书架主屏与卡片）
  - 现状：本地 `onUnavailableAction('网址导入尚未迁移')`
- `BOOKSHELF.md:122` **来源标签（搜索模式）**（A1 书架主屏与卡片）
  - 现状：本地书架无搜索模式下的来源命中高亮
- `BOOKSHELF.md:145` **批量下载**（A1 书架主屏与卡片）
  - 现状：同上
- `BOOKSHELF.md:273` **顶栏分享**（B 书籍详情页与元数据）
  - 现状：本地 `onUnavailableAction('书籍分享尚未迁移')` ；**复核（r341）**：本批未做，原因 上游分享走书源回调 CLICK_SHARE_BOOK，本地无书源引擎；顺延批 13
- `BOOKSHELF.md:275` **菜单·书源自定义按钮**（B 书籍详情页与元数据）
  - 现状：依赖书源自定义按钮体系。在线书源抓取自 2026-11-09 起**已纳入范围、尚未排期**（[项目队列](../PROJECT.md) `:24-44`），故由 `不适用` 改判 `未接`，排期时随书源模块一起做
- `BOOKSHELF.md:277` **菜单·分享**（B 书籍详情页与元数据）
  - 现状：同顶栏分享 ；**复核（r341）**：本批未做，原因 与 :273 同一动作的另一入口，同顺延批 13
- `BOOKSHELF.md:283` **菜单·登录书源**（B 书籍详情页与元数据）
  - 现状：本地无书源登录体系
- `BOOKSHELF.md:285` **菜单·设置书源变量**（B 书籍详情页与元数据）
  - 现状：本地无书源变量
- `BOOKSHELF.md:286` **菜单·设置书籍变量**（B 书籍详情页与元数据）
  - 现状：同上
- `BOOKSHELF.md:287` **菜单·复制书籍链接**（B 书籍详情页与元数据）
  - 现状：本地无剪贴板动作 ；**复核（r341）**：本批未做，原因 显示条件 bookSourceUi != null 且动作走书源回调 CopyText(book.bookUrl)；顺延批 13
- `BOOKSHELF.md:288` **菜单·复制目录链接**（B 书籍详情页与元数据）
  - 现状：同上 ；**复核（r341）**：本批未做，原因 同上，CopyText(book.tocUrl)；顺延批 13
- `BOOKSHELF.md:324` **相关书籍横幅**（B 书籍详情页与元数据）
  - 现状：本地无相关书籍推荐
- `BOOKSHELF.md:345` **书源回调按钮**（B 书籍详情页与元数据）
  - 现状：本地无书源回调体系
- `BOOKSHELF.md:349` **作者其他作品**（B 书籍详情页与元数据）
  - 现状：本地无
- `BOOKSHELF.md:439` **卡片下载/停止按钮**（D2 缓存管理页 · 书籍卡片与章节）
  - 现状：同上 ；**复核（r341）**：本批未做，原因 本地正文就是磁盘上那一个整本文件，没有「下载」这个动作；依赖在线书源逐章可下载，本批未做
- `BOOKSHELF.md:441` **章节行（下载状态）**（D2 缓存管理页 · 书籍卡片与章节）
  - 现状：本地无章节级缓存视图 ；**复核（r341）**：本批未做，原因 需要逐章缓存才有意义，本地整本导入、章节级无独立状态；依赖在线书源，本批未做
- `BOOKSHELF.md:467` **选择模式·批量换源**（D3 书架管理页）
  - 现状：同上 ；**顺延（r341）**：依赖在线书源体系（书源选择与换源），随批 13 在线书源模块排期，本批未做
- `BOOKSHELF.md:475` **自定义 EPUB 导出**（D3 书架管理页）
  - 现状：同上 ；**顺延（r341）**：要先有 EPUB 打包器（本地 EpubRepository 只读不写），随批 13 在线书源模块排期，本批未做
- `BOOKSHELF.md:477` **书源选择面板**（D3 书架管理页）
  - 现状：同上 ；**顺延（r341）**：依赖书源体系列出可用书源，随批 13 在线书源模块排期，本批未做
- `BOOKSHELF.md:478` **换源预览面板**（D3 书架管理页）
  - 现状：同上 ；**顺延（r341）**：依赖书源体系逐本预览换源结果，随批 13 在线书源模块排期，本批未做
- `BOOKSHELF.md:479` **其它书源选项**（D3 书架管理页）
  - 现状：同上 ；**顺延（r341）**：依赖书源体系的保留项勾选，随批 13 在线书源模块排期，本批未做
- `READER-CONFIG.md:92` **自动切换书源**（A 阅读界面基础）
  - 现状：走 `showNotMigrated('自动切换书源')`
- `READER-CONFIG.md:93` **换源结果应用于全部书籍**（A 阅读界面基础）
  - 现状：走 `showNotMigrated('换源结果应用于全部书籍')`
- `READER-CONFIG.md:103` **向后预下载章节数**（A 阅读界面基础）
  - 现状：**复核（r348）：持久化在，缺消费方。** `preloadBehind` 在 `data/CacheSettingsRepository.ets` 与设置页之间往返正常，但除这两处外**全仓零消费**（`preloadBehind|preloadAhead|preDownloadNum` 共 12 处命中，全在仓储与设置页）→ 调大不驱动任何缓存动作。原「`:31` 是预览页、滑块无持久化」为误：该文件 186 行，`:31` 是 `@State cacheSettings` 初始化。
- `READER-CONFIG.md:104` **向前预下载章节数**（A 阅读界面基础）
  - 现状：同上：字段在、往返正常、无消费方。
- `TXT-READER.md:295` **标题胶囊右端书源圆点（8dp，热区 24dp×满高）→ 登录/付费/编辑书源/禁用书源**（C2 顶栏）
  - 现状：本地只有本地书，没有书源概念。在线书源抓取自 2026-11-09 起**已纳入范围、尚未排期**（[项目队列](../PROJECT.md) `:24-44`），故由 `不适用` 改判 `未接`
- `TXT-READER.md:299` **顶栏长按二级菜单（长按换源 → 换源/更换本章源；长按刷新 → 刷新本章/刷新后续）**（C2 顶栏）
  - 现状：本地无书源，换源与刷新都不存在。在线书源抓取自 2026-11-09 起**已纳入范围、尚未排期**（[项目队列](../PROJECT.md) `:24-44`），故由 `不适用` 改判 `未接`
- `TXT-READER.md:343` **章节右侧状态图标（字数卡 / 定位 / 下载中 / 成功 / 失败 / 本地空占位），切换 fade 200ms + scale 0.8**（C5 目录页）
  - 现状：本地 TXT 全离线，不存在下载状态图标。在线书源抓取自 2026-11-09 起**已纳入范围、尚未排期**（[项目队列](../PROJECT.md) `:24-44`），故由 `不适用` 改判 `未接`
- `TXT-READER.md:480` **目录跳转加载态**（D7 目录跳转）
  - 现状：本地全离线，章节内容从本地文件读，无下载态。在线书源抓取自 2026-11-09 起**已纳入范围、尚未排期**（[项目队列](../PROJECT.md) `:24-44`），故由 `不适用` 改判 `未接`
- `ZIP-BOOKSHELF-LAYOUT.md:92` **显示等待更新数量**（A 设置面板）
  - 现状：面板有（`showWaitUpCount`，`pages/BookshelfPage.ets:1873-1875`），但 `pages/` 与 `components/` 里除面板外零消费 —— 上游把它算成 `postUpBooksCount()`（`BookshelfViewModel.kt:1289`）喂进标题末尾的「(N)」，本地书名行没有这个尾巴；且待更新书数需要在线书源，本地无书源时恒为 0
- `ZIP-BOOKSHELF-LAYOUT.md:99` **书架更新数量限制**（A 设置面板）
  - 现状：面板有（`bookshelfRefreshingLimit`，`pages/BookshelfPage.ets:1931-1937`，步进器 0..100，0 表示不限），但除面板外零消费 —— 本地没有批量更新入口（`BookRepository.refreshToc` 只处理单本），上游 `refreshBooks` 的 `take(limit)`（`BookshelfViewModel.kt:1114-1115`）没有对应物
- `ZIP-BOOKSHELF-LAYOUT.md:199` **等待更新数量**（E 书架主屏）
  - 现状：面板有（`showWaitUpCount`，`pages/BookshelfPage.ets:1873-1875`），但除面板外 `pages/` 与 `components/` 零消费；上游把 `postUpBooksCount()` 喂进书名末尾的「(N)」，本地书名行没有该尾巴，且无在线书源时待更新数恒为 0
- `ZIP-BOOKSHELF-LAYOUT.md:200` **批量更新数量限制**（E 书架主屏）
  - 现状：面板有（`bookshelfRefreshingLimit`，`pages/BookshelfPage.ets:1931-1937`），但除面板外零消费；本地无批量更新入口（`BookRepository.refreshToc` 只处理单本），上游两处 `take(limit)` 都没有对应物
- `ZIP-BOOKSHELF-LAYOUT.md:201` **打开书架时自动刷新目录**（E 书架主屏）
  - 现状：字段存在（`model/BookshelfLayout.ets:59 autoRefreshBook`，备份键 `auto_refresh` 在 `data/BackupRepository.ets:933` 写出），但 `pages/` 与 `components/` **零命中** —— 没有任何地方读它，进书架不会触发刷新；且本地无在线书源，目录刷新无对象
- `ZIP-COVER.md:86` **A1 仅 WiFi 下载封面**（A 封面设置页）
  - 现状：本地已有字段、已有开关、已参与备份往返（`data/BackupRepository.ets` 的 14 键之一），**缺的是消费端**：`loadOnlyOnWifi` 在 `entry/src/main/ets` 内除设置页与仓储外零命中——本地没有网络封面加载链路（离线工程），这个开关拨了不影响任何画面。上游的消费者是图片请求的 `loadOnlyWifiOption`：`model/BookCover.kt:129`、`CoilBookCover.kt:227`、`ui/main/bookshelf/Boo…
- `ZIP-COVER.md:146` **C6 规则求值：`searchCover` 的输入输出与失败路径**（C 封面规则）
  - 现状：本地无求值。唯一调用点：`ui/book/info/BookInfoViewModel.kt:1275`（在 `:1272-1290 upCoverByRule` 内），前置条件 `:1274 book.coverUrl.isNullOrBlank() && book.customCoverUrl.isNullOrBlank()`——**只在「既没有网络封面 URL 也没有自定义封面」时才去搜**，成功则写 `book.customCoverUrl`，书在书架里时 `saveBook`。失败路径全部落到「返回 nu…

### G 依赖 TTS/朗读（已纳入范围，未排期）

> **卡点**：朗读自 2026-11-09 起**已纳入范围**（`docs/PROJECT.md:24-44`），尚未排期；TTS 引擎整体未接。
>
> **怎么解**：按朗读批次排期。

- `READER-CONFIG.md:91` **朗读悬浮窗分离提醒**（A 阅读界面基础）
  - 现状：走 `showNotMigrated('朗读悬浮窗分离提醒')`
- `READER-CONFIG.md:216` **朗读时允许音量键翻页**（D 翻页与手势交互）
  - 现状：走 `showNotMigrated('朗读时音量键翻页')`
- `TXT-READER.md:346` **目录多选里的「下载选中 / 删除角色分配 / 删除朗读音频」**（C5 目录页）
  - 现状：上游这三项分别属于章节下载、朗读角色分配、朗读音频，本地 TXT 阅读没有下载与朗读链路。在线书源与 TTS 自 2026-11-09 起**已纳入范围、尚未排期**（[项目队列](../PROJECT.md) `:24-44`），故由 `不适用` 改判 `未接`
- `TXT-READER.md:406` **每格 14/15 种动作可选（无/菜单/下一页/上一页/下一章/上一章/朗读上一段/朗读下一段/加书签/编辑正文/切换替换/目录/搜索/同步进度/朗读暂停）**（D1 点击分区）
  - 现状：**复核（r348）：选项一个不缺，缺的是行为。** 上游 `ReaderTapAction.kt:3-17` 枚举 15 项（`NONE(-1)` … `TOGGLE_READ_ALOUD_PAUSE(13)`），本地 `READER_CLICK_REGION_ACTIONS` 也是 15 项、顺序一致（首项本地写「无操作」对应上游 `NONE`）。真缺口在 `performReaderTapAction`：它只处理 12 项，`朗读上一段` / `朗读下一段` / `朗读暂停/继续` 三项落到末行 `onUna…
- `ZIP-BOOKMARK.md:216` **朗读**（F1 菜单项本体）
  - 现状：底栏 `voice` 也走同一句「朗读播放尚未迁移」，TTS 整体未接
- `ZIP-BOOKMARK.md:225` **插入 BGM（段前）**（F1 菜单项本体）
  - 现状：无音频插入能力（朗读与播放整体未接）
- `ZIP-BOOKMARK.md:226` **插入 BGM（段后）**（F1 菜单项本体）
  - 现状：同上

### H 依赖 AI 在线服务（范围之外，按用户口径仍记未接）

> **卡点**：属 `docs/PROJECT.md:48-50` 明列的「AI 在线服务」范围之外。**按用户口径（只认平台无能力）仍记 `未接`**，但注明它卡在范围决策而非平台。
>
> **怎么解**：要么改范围决策，要么维持不做——这是产品判断不是技术障碍。

- `ZIP-BOOKMARK.md:222` **AI 清洗**（F1 菜单项本体）
  - 现状：只有 `CONTENT_PROCESS_KIND_AI_CLEAN` 常量与 `BookContentProcess` 记录类型，无 AI 调用；AI 助手整体不在范围
- `ZIP-BOOKMARK.md:223` **AI 改写**（F1 菜单项本体）
  - 现状：同「AI 清洗」

### I 缺本地数据层/实体（表或字段没建）

> **卡点**：上游读的是本地表/字段，本地没有对应实体。属「还没建数据层」。
>
> **怎么解**：建表 + 建实体 + 补写入方。

- `BOOKSHELF.md:520` **该表的数据来源：首次打开数据库时从 `assets/defaultData/keyboardAssists.json` 灌 32 条默认值**（E 备份恢复）
  - 现状：上游的 32 条默认数据只在「该表为空」时灌一次，灌完就是数据库里的行；本地没有这张表，也没有这 32 条的落点。这 32 条的内容是书源规则语法符号（`@css:`、`<js>`、`{{}}`、`class`、`textNodes`、`useWebView` 等），不是键码
- `TXT-READER.md:381` **高亮规则编辑：命中排版（字前距/字后距/行上距/行下距）、应用排版 chip、字体替换、九宫格切图编辑器（250dp 画布、2dp 绿色切分线、4 个 5dp 手柄、拖拽命中 32dp）**（C7 二级面板）
  - 现状：本地编辑器已补齐四块中的三块并在设备上验证：**命中排版**（字前距/字后距/行上距/行下距四个步进，0~40 dp 步 0.5）、**字体替换**（选本地字体 + 清空 + 字重循环 + 斜体开关 + 字号偏移 -10~10 sp）、**文字背景图**（选图 + 填充方式 + 缩放 + 左右伸出 + 九宫格切线与手动切图）。缺的只有**应用排版 chip**：本地没有「命名排版方案」这个实体（`READER_BACKGROUND_STYLES` 只有背景色，无完整排版参数），chip 没有数据源可列。因此这一行整…
- `ZIP-BOOKMARK.md:219` **词典**（F1 菜单项本体）
  - 现状：本地有 `dictRule` 备份类别与 `LocalTextReSegmenter` 里的局部 `dict` 变量，但无查词能力
- `ZIP-COVER.md:131` **B15 旧版封面迁移（`migrateLegacyCoversIfNeeded`）**（B 默认封面相册）
  - 现状：上游迁移方向是「旧的两个偏好键（逗号串绝对路径）→ 相册 `default-cover`」，迁移后**旧键仍被回写**（`syncLegacyCoverPaths`），所以新旧两套读法并存：`CoverAlbumRepository.kt:294-301` 写、`:242-247` 读。本地两套都没有，因此沿用旧版 `defaultCover` 设置的用户升级后会看到「未选择相册」，封面回落到随机默认图。样本备份 `N:\HarmonyProjects\测试\backup2026-10-22\config.xml:…

### J 缺前置模块（排版引擎/缓存体系/编辑器）

> **卡点**：上游能力长在阅读器排版引擎、章节缓存表或正文编辑器上，本地这几块还没建。
>
> **怎么解**：先补前置模块，再做这一层。

- `BOOKSHELF.md:290` **菜单·长按分章**（B 书籍详情页与元数据）
  - 现状：`splitLongChapter` 全仓 0 命中 ；**复核（r341）**：本批未做，原因 splitLongChapter 全仓零命中且会改排版引擎，属阅读器域；移出本表批次
- `BOOKSHELF.md:292` **菜单·清除缓存**（B 书籍详情页与元数据）
  - 现状：本地无章节缓存体系 ；**复核（r341）**：本批未做，原因 依赖批 8 的磁盘章节缓存表，现在清的是内存 Map、重启即空；移入批 8
- `READER-CONFIG.md:89` **优化正文渲染**（A 阅读界面基础）
  - 现状：走 `showNotMigrated('优化正文渲染')`
- `TXT-READER.md:83` **目录解析流式读取（512000 字节/块），不整本进内存**（A1 打开与加载）
  - 现状：本地切章仍要**先把整本读成字符串**再切，上游按 512000 字节块扫标题。100MB 级 TXT 本地会先卡住再出目录，上游目录页先出来。本轮没改这条：改动面涉及 `splitChapters`、`buildChapterRows`、`forEachChapter` 全套偏移换算，收益只在 50MB+ 大书。
- `TXT-READER.md:123` **正文 8MB 窗口缓存，不整本常驻**（A4 字数统计与大文件）
  - 现状：打开一本 100MB 的 TXT 后，本地内存里会长期压着一整本字符串，切到别的书才释放；上游只保留 8MB 窗口。低内存设备上表现为看书久了被系统杀后台。本轮没改：需要把 `splitChapters` / `readChapter` / `forEachChapter` 全部改成按窗口取文，改动面大于本轮批次。
- `TXT-READER.md:161` **图片缓存：两种尺寸各缓存一份**（B3 预取与缓存）
  - 现状：本地只按一个尺寸缓存 32 张、超了先进先出；上游按两种尺寸各留一份。图文混排的书（每章十几张图）本地翻几页就会反复重解码，表现为**图片慢慢浮现**。
- `TXT-READER.md:163` **滚动模式整页 PixelMap 缓存（容量 8 的 LRU，key 用元素引用身份）**（B3 预取与缓存）
  - 现状：滚动模式下本地每帧重绘整页文字，上游缓存 8 页位图。长章滚动时本地 CPU 占用更高，低端机上**滚动会掉帧**。
- `TXT-READER.md:181` **折页角点选择（按触点落在上半/下半页决定从哪个角卷起）**（B4 绘制与转场）
  - 现状：代码通路已接：拖动时每帧按触点上下半页重算卷起角与触点位置。但**纸张卷曲形状是否真的跟着手指同步**还没在真机上确认——模拟器 `snapshot_display` 抓不到拖动中间帧（连拍 8 张字节数全等），只能证明回调每帧都进，证明不了画面。按「已接必须指到屏幕位置」的口径，仍判未接。
- `TXT-READER.md:237` **正文三槽常驻：换章只平移槽位，不重读正文**（B8 跨章换页与页窗口拼接）
  - 现状：上游换章时 `next` 槽里的正文已经是内存里的 `List<String>`，`moveReaderChapterInputNext()` 只是把三个引用挪一格，**零 IO**；本地换章必然触发一次正文读取与语义解析。用户可感知的差别是：上游往回翻一章时瞬间就有内容（`previous` 槽还在），本地要重新读+重排。
- `TXT-READER.md:238` **分页器一次只排一章，页成型即经 `onPage` 流式流出**（B8 跨章换页与页窗口拼接）
  - 现状：上游第一页排好就能上屏，后续页边排边追加；本地必须等整章排完才有第一页。章越长差别越大——一本 3 万字一章的 TXT，本地要等整章排版结束才显示第一页，上游首屏几乎立即出现。
- `TXT-READER.md:244` **章末页额外留 20dp 空档、只加在最后一页、不向内容区高度收口、且延迟一页流出**（B8 跨章换页与页窗口拼接）
  - 现状：上游章末那一页在**滚动堆叠高度**上多留 20dp，下一章的第一页从这个空档之后开始——滚动时用户看到章末正文下面有一条窄空档，紧接着就是下一章标题，两章在视觉上连成一条。本地没有这个 20dp，也没有「章末页延迟一页流出」的判定（本地一次排完整章，天然知道哪页是最后一页），所以本地做不到「上一章末尾与下一章开头同帧相接」。注意：B1 有一条「章末留白 20dp」判已接，盘的是**分页模式**的章末留白（`ReaderPaginator.kt:1149`）；本行盘的是**滚动模式**下这个值参与堆叠高度、以及它带…
- `TXT-READER.md:245` **增量发布策略：只发布「当前页附近」的流式页，避免中途整表替换**（B8 跨章换页与页窗口拼接）
  - 现状：上游排版过程中每来一页都要判断「这一页要不要立刻发布」——离当前阅读位置太远的先不发布，避免页表在用户眼前反复重排。本地没有流式发布，也就没有这个判断；对应的问题是整表一次性赋值，视觉上是一次跳变而非渐进。
- `TXT-READER.md:269` **标题与正文共用同一个折行器，无标题专属折行分支**（B9 标题块在排版流里）
  - 现状：正文断行已交给系统原生引擎，**标题仍逐 cluster 硬切**，两者折行规则不同：标题是一长串英文单词时，本地会在单词中间断开，上游按词断。原因是标题各段字号按 `fontSizeScale` 缩放、字体族是 `readerTitleFontFamily`，与正文的 `ReaderTextLayoutStyle` 不是一套，`ReaderTextLayoutEngine` 一次只描述一种字体样式。
- `ZIP-BOOKMARK.md:221` **编辑（正文）**（F1 菜单项本体）
  - 现状：无正文编辑入口。`ReaderSettingsPage.ets:36` 的 `menu_edit` 只是菜单清单里的一个 id 与图标，不是功能

### K 依赖平台能力（须自研或引三方库）

> **卡点**：平台 `@ohos.zlib` 只支持 zip / gzip / tar，**没有 rar / 7z 解压 API**；上游靠 `me.zhanghai.android.libarchive` 的 C++ libarchive。这是**真正的平台缺失**，但按用户口径它是「要多花工」，不是「不适用」。
>
> **怎么解**：三条路：自研解码器 / 引入三方 HAR / 维持仅 zip+cbz。

- `TXT-READER.md:594` **`.rar` / `.7z` 后缀**（I 压缩包导入层）
  - 现状：**这一条是整块唯一的真障碍**：上游靠原生库 `me.zhanghai.android.libarchive`（`gradle/libs.versions.toml:36` `libarchive = "1.1.6"`、`:181` 模块坐标、`app/build.gradle.kts:255`）走 C++ libarchive；鸿蒙侧没有等价的开箱能力，要做只能自己写 rar / 7z 解码或找三方库。用户可感知的差别：rar / 7z 打包的书在本地完全导入不进来。 **当前状态（r344）**：zip / …

### L 纯本地功能未做（平台支持、缺入口或面板）

> **卡点**：平台支持、能力也大多已在（`lib/AppLog.ets`、`systemShare`、`startAbility`、`DocumentViewPicker` FOLDER 模式、`ArchiveImporter`、`lib/WebDav.ets`、`OnlineBookService` 章节缓存），**缺的是入口、面板或开关本身**。
>
> **怎么解**：排期即可做，无外部阻塞。

- `BOOKSHELF.md:278` **菜单·上传书籍**（B 书籍详情页与元数据）
  - 现状：本地无 WebDAV 上传 ；**复核（r341）**：本批未做，原因 需 RemoteBookRepository 单本上传与 serverID，本地 WebDAV 只有备份级 API；顺延批 13
- `BOOKSHELF.md:279` **菜单·同步到远端**（B 书籍详情页与元数据）
  - 现状：同上 ；**复核（r341）**：本批未做，原因 需远端书籍目录结构与 getRemoteUrl() 语义；顺延批 13
- `BOOKSHELF.md:289` **菜单·允许更新**（B 书籍详情页与元数据）
  - 现状：`Book.ets` 缺 `canUpdate` 字段 ；**复核（r341）**：本批未做，原因 条件 isLocal == false，本地 readBookRow 把 isLocal 写死 true，这一项永远不该出现；顺延批 13
- `BOOKSHELF.md:293` **菜单·显示日志**（B 书籍详情页与元数据）
  - 现状：本地无日志页 ；**复核（r341，收口修正理由）**：本批未做。当日判据「全仓没有日志设施」已被证伪——`entry/src/main/ets/lib/AppLog.ets` 是 500 条环形缓冲（put / getAll / clear），`pages/BookshelfPage.ets:1961` 已有 `LogSheetContent()` 面板。真正缺的是详情页更多菜单没有这一项：`pages/BookInfoPage.ets:361-374 BookInfoMoreMenu()` 只有设为私密、置顶、…
- `BOOKSHELF.md:303` **加入书架（含冲突提示）**（B 书籍详情页与元数据）
  - 现状：本地入口只在书架内，无「加入」动作与同名冲突高亮 ；**复核（r341）**：本批未做，原因 本地 openBookInfo 调用方只有书架 / 首页 / 阅读器菜单，没有非书架来源，动作卡首项永远「已在书架」；顺延批 13
- `BOOKSHELF.md:305` **长按加入书架选分组**（B 书籍详情页与元数据）
  - 现状：本地无此手势 ；**复核（r341）**：本批未做，原因 同 :303，无「非书架书进详情页」路径；顺延批 13
- `BOOKSHELF.md:314` **摘要·目录加载失败提示**（B 书籍详情页与元数据）
  - 现状：本地无 `error_load_toc` 等价提示 ；**复核（r341）**：本批未做，原因 本地详情页不读取章节列表（目录在目录页加载），没有「目录加载失败」这个状态，硬造假状态比不做更糟；本批未做
- `BOOKSHELF.md:317` **简介·HTML 渲染**（B 书籍详情页与元数据）
  - 现状：本地无 `<usehtml>` 分支
- `BOOKSHELF.md:318` **简介·Web 渲染**（B 书籍详情页与元数据）
  - 现状：本地无 `<useweb>` 分支与 WebView 桥
- `BOOKSHELF.md:319` **简介·Markdown 渲染**（B 书籍详情页与元数据）
  - 现状：本地无 `<md>` 分支
- `BOOKSHELF.md:340` **面板·分组多选**（B 书籍详情页与元数据）
  - 现状：上游为独立面板（标题 + 新建分组 + 逐行编辑 + 位掩码选择）；本地把多选塞在元数据编辑面板内 ；**复核（r341）**：本批未做，原因 本批未做独立 GroupSelectSheet：元数据面板内仍是逐行 Checkbox 多选，差一个独立面板入口与面板内「＋ 新建分组」；状态保持未接
- `BOOKSHELF.md:341` **面板·在线换封面**（B 书籍详情页与元数据）
  - 现状：本地只能从相册选图或还原，无在线搜封面 ；**复核（r341）**：本批未做，原因 需按 URL 取图，本地零先例；顺延批 13
- `BOOKSHELF.md:342` **面板·网络文件选择**（B 书籍详情页与元数据）
  - 现状：本地无网络文件导入 ；**复核（r341）**：本批未做，原因 需网络文件的读取与缓存；顺延批 13
- `BOOKSHELF.md:343` **面板·压缩包条目选择**（B 书籍详情页与元数据）
  - 现状：本地无压缩包导入 ；**复核（r341）**：本批未做，原因 需 ZIP 单条目列举，本地只有整包解压；顺延批 13
- `BOOKSHELF.md:344` **面板·不支持文件提示**（B 书籍详情页与元数据）
  - 现状：本地无 ；**复核（r341）**：本批未做，原因 依赖 :342 / :343 的文件类型判定；顺延批 13
- `BOOKSHELF.md:347` **简介内按钮点击**（B 书籍详情页与元数据）
  - 现状：本地无 `<button>` 解析
- `BOOKSHELF.md:348` **简介图片点击与长按**（B 书籍详情页与元数据）
  - 现状：本地无简介图片交互
- `BOOKSHELF.md:350` **目录选择（book tree uri）**（B 书籍详情页与元数据）
  - 现状：本地无 SAF 目录授权 ；**复核（r341）**：本批未做，原因 Android SAF 目录授权在鸿蒙无对应物；顺延批 13
- `BOOKSHELF.md:442` **章节状态六档文字**（D2 缓存管理页 · 书籍卡片与章节）
  - 现状：上游六档：下载中/失败待重试/等待/暂停/失败/已缓存 ；**复核（r341）**：本批未做，原因 上游章节状态档位（ChapterCacheStatus.kt）全部依赖下载器状态，本地无下载器；本批未做
- `BOOKSHELF.md:443` **章节下载/暂停/删除**（D2 缓存管理页 · 书籍卡片与章节）
  - 现状：同上 ；**复核（r341）**：本批未做，原因 同上，依赖逐章可下载；本批未做
- `BOOKSHELF.md:445` **删除章节缓存确认框**（D2 缓存管理页 · 书籍卡片与章节）
  - 现状：本地无 ；**复核（r341）**：本批未做，原因 同上，依赖逐章缓存；本批未做
- `BOOKSHELF.md:446` **长按卡片进选择**（D2 缓存管理页 · 书籍卡片与章节）
  - 现状：本地无选择模式 ；**复核（r341）**：本批未做，原因 上游选择模式用于批量下载/换源/清缓存，本地无下载无换源，批量只剩「删除」且与书架选择模式（批 5）重复；本批未做
- `READER-CONFIG.md:96` **使用新版目录**（A 阅读界面基础）
  - 现状：走 `showNotMigrated('使用新版目录')`
- `READER-CONFIG.md:102` **主题网格列数**（A 阅读界面基础）
  - 现状：**复核（r348）：控件在，但只存页面状态。** `themeGridColumns` 全仓 4 处命中且全在 `ReaderSettingsPage.ets`（`:390`/`:1961`/`:1966`/`:2696`），`data/ReaderSettingsRepository.ets` 与 `data/BackupRepository.ets` 均零命中 → 退出阅读设置页即丢，重进回到 4。上游 `ReadSettings.kt:40` 是持久化字段。
- `READER-CONFIG.md:105` **在浏览器打开**（A 阅读界面基础）
  - 现状：上游 `readUrlInBrowser`，本地无字段
- `READER-CONFIG.md:195` **字体文件夹**（C 正文排版）
  - 现状：上游 `fontFolder` 指定扫描目录，本地只支持系统字体与内置字体
- `TXT-READER.md:353` **目录多选批量：从最后起选（`selectFromLast`，把最后一个已选项之后的所有项加进选择）**（C5 目录页）
  - 现状：上游多选次级菜单有五项（反选 / **从最后起选** / 加书签 / 删除角色分配 / 删除朗读音频），本地只有「全选」「反选」两项（另三项本地不适用，已有行）。缺的这一项用途是：先手动点选几章，再从最后一个已选项往后全选——给「从第 50 章往后全部加书签」这类操作省掉逐页翻。屏幕现象：本地多选工具条的「操作」菜单里没有「从最后起选」这一项。
- `ZIP-BOOKMARK.md:100` **书签无障碍播报**（A 阅读页书签）
  - 现状：本地无阅读页无障碍策略层，`entry/src/main/ets` 全仓只有一处 `accessibilityText`（`ProfileSubPages.ets:3579`，与阅读无关）
- `ZIP-BOOKMARK.md:110` **划词菜单「替换」项（预填规则）〔r286 起该项整体归 F 块，此处只留归属〕**（B 阅读页划线 / 笔记）
  - 现状：规则编辑器完整，但只接受整条 `ReplaceRule` 回填，**没有预填 pattern 的草稿通道**
- `ZIP-BOOKMARK.md:111` **划词菜单其余 8 项（分享 / 浏览器 / 朗读 / 词典 / 正文编辑 / AI 清洗 / AI 改写 / 插入 BGM）**（B 阅读页划线 / 笔记）
  - 现状：本地确实无对应能力：分享全仓无 `systemShare`；浏览器全仓无 `startAbility`，`module.json5` 无 browser skill；朗读 `ReaderPage.ets:1286` 明确「朗读播放尚未迁移」；词典 / 正文编辑 / AI 清洗 / AI 改写 / BGM 全仓零功能实现
- `ZIP-BOOKMARK.md:123` **标记渲染前校验锚点文本**（B 阅读页划线 / 笔记）
  - 现状：本地只判 `chapterPosition < end && endPosition > start` 相交，**完全不看 `selectedText`**；等价能力 `BookContentProcessEngine.ets:93 findTargetRange` 已存在但没接到标记渲染
- `ZIP-BOOKMARK.md:127` **划词菜单「行内快速标记」模式**（B 阅读页划线 / 笔记）
  - 现状：本地只有 sheet 一条路径，无 inline 预览态（`previewStyle` / `inlineDirty` 未建模）
- `ZIP-BOOKMARK.md:146` **信息页四行（作者 / 书源 / 备注 / 简介）**（C 目录页信息 / 书签 / 笔记三 tab）
  - 现状：本地只有作者（`:334`）、书源（`:335`）、简介（`:336-338`）三行，**缺「备注」行**；本地 `model/Book.ets:46 remark?: string` 字段存在，只是界面没渲染。上游 `:531` 是 `remark.takeIf { it.isNotBlank() }` 条件显示，本地补时照抄条件即可
- `ZIP-BOOKMARK.md:152` **书签/笔记多选与批量操作**（C 目录页信息 / 书签 / 笔记三 tab）
  - 现状：章节行与书签条目都只有单击，无选择模式
- `ZIP-BOOKMARK.md:153` **书签/笔记反序**（C 目录页信息 / 书签 / 笔记三 tab）
  - 现状：本地无排序方向开关，恒按章节升序
- `ZIP-BOOKMARK.md:214` **分享**（F1 菜单项本体）
  - 现状：全仓无 `systemShare`；`BookInfoPage.ets:269` 自身也是「书籍分享尚未迁移」
- `ZIP-BOOKMARK.md:215` **浏览器打开**（F1 菜单项本体）
  - 现状：全仓无 `startAbility`，`module.json5` 无 browser skill
- `ZIP-BOOKMARK.md:220` **替换**（F1 菜单项本体）
  - 现状：规则编辑器完整，缺「预填 pattern」草稿通道；`Index.ets` 只暴露 `openReplaceRuleEditor(id)`
- `ZIP-BOOKMARK.md:224` **全文搜索**（F1 菜单项本体）
  - 现状：搜索页完整（历史/正则/替换开关），但 `aboutToAppear`（`:52`）无 `initialQuery` 入参
- `ZIP-BOOKMARK.md:236` **默认形态：一排主项 + 「更多」浮层**（F2 菜单形态）
  - 现状：本地是单行 `Row`，没有「更多」与浮层
- `ZIP-BOOKMARK.md:237` **展开形态：多行平铺**（F2 菜单形态）
  - 现状：无多行形态
- `ZIP-BOOKMARK.md:238` **两套形态按 `expandTextMenu` 切换**（F2 菜单形态）
  - 现状：配置页有这个开关，但只是页面 `@State`，不持久化、不生效
- `ZIP-BOOKMARK.md:239` **显示/隐藏菜单图标开关**（F2 菜单形态）
  - 现状：同上，仅预览态
- `ZIP-BOOKMARK.md:250` **拖拽排序（长按拖动）**（F3 配置页自身）
  - 现状：本地只有箭头点按，无拖拽
- `ZIP-BOOKMARK.md:251` **保存按钮**（F3 配置页自身）
  - 现状：按钮在，点击走 `onUnavailableAction('选中文字菜单配置尚未保存')`，页面自己写着「均为预览，保存功能尚未迁移」
- `ZIP-BOOKMARK.md:252` **无障碍播报（重排提示）**（F3 配置页自身）
  - 现状：本地无该项播报
- `ZIP-BOOKMARK.md:258` **菜单配置落盘**（F4 持久化链路）
  - 现状：`grep -rn textSelectMenuConfig entry/src/main/ets` 零命中，配置页的三档状态只活在 `@State`
- `ZIP-BOOKMARK.md:259` **配置项结构 `{id, enabled, showState}`**（F4 持久化链路）
  - 现状：本地少了 `enabled` 维度（上游可单项禁用而不移出列表）
- `ZIP-BOOKMARK.md:260` **按配置顺序重排菜单**（F4 持久化链路）
  - 现状：阅读页菜单是硬编码 3 项，不读任何配置
- `ZIP-BOOKMARK.md:261` **两个开关的偏好键**（F4 持久化链路）
  - 现状：未接进 `ReaderSettingsRepository`
- `ZIP-BOOKSHELF-LAYOUT.md:161` **首屏封面预加载列数**（C 布局矩阵）
  - 现状：本地无封面预加载器（`grep -rn 'preload|Preload' entry/src/main/ets` 零命中），按任务书 `:166-168` 处置为「记录为无预加载器、按 0 处理」，不新建预加载系统；封面由 `components/BookCover.ets` 各卡片自行加载。功能本身不新建，按任务书 `:200` 留 `未接`，卡点见证据包第 4 节
- `ZIP-COVER.md:95` **A10 网络书籍角标**（A 封面设置页）
  - 现状：本地已有字段、四档选择条目、备份往返，**缺的是消费端**：`exploreFilterState` 在 `entry/src/main/ets` 内除设置页与仓储/备份外零命中；本地的 `pages/DiscoverPage.ets:62` 只是对本地示范数据做 `filter`，不读这个字段。上游唯一消费者是 `ui/book/explore/ExploreShowViewModel.kt:249` `filterStateId = coverSettings.exploreFilterState`。**这个键…
- `ZIP-COVER.md:149` **C9 规则的忽略开关（`backupIgnoreCoverConfig` / `ignoreCoverConfig`）**（C 封面规则）
  - 现状：本地只有「整个 `coverConfig` 类别一起打包/不打包」的粗粒度开关，**没有「只跳过封面规则」的细粒度开关**。上游两个开关是独立偏好项：可以在保留 14 个设置键的同时跳过 `coverRule.json`
- `ZIP-COVER.md:180` **D18 封面预加载（首屏批量预取）**（D 封面渲染）
  - 现状：本地 `.ets` 内 `preload`/`预加载` **零命中**——没有预取器，封面图完全依赖 `Image(book.coverUri)` 自己的加载（本地封面全是本地文件 URI，见 `data/BookRepository.ets:894`/`:955 resolveCoverUri`、`data/EpubRepository.ets:109`）。所以本地的「首屏出图速度」问题不存在（本地图不走网络），而 `loadOnlyOnWifi` 这个前置条件在本地也无从谈起
- `ZIP-THEME.md:161` **D4 主题列表页的日夜切换按钮**（D 阅读页日夜快捷按钮）
  - 现状：本地**没有主题列表页**（`pages/` 34 个文件里无对应页面，阅读页也没有「主题列表」sheet），按钮所在页面整体未迁移。2026-11-09 由 `不适用` 改判 `未接`：原备注用的「上游有、本地整页没有则标不适用」不在 `docs/PARITY-RULES.md` 第三节的四类依据里（不是上游无此行为、不是平台无此能力、不在范围之外、也不是数据层无独立界面），按该节末句「一条依据都写不出，就不能判 `不适用`——降级为 `未接`」改判

---

## 三、本轮上机验证记录

设备：`127.0.0.1:5555`，`const.product.model` = `emulator`，应用 `io.legado.harmony`。

**被测应用与源码的对应关系（先钉死，避免误读）**：设备上该应用的 `bm dump` `updateTime` = 2026-11-20 17:39:59。本轮验证涉及的每个源文件的最后一次提交都在这个时刻之前：

| 文件 | 最后改动提交 | 时间 |
| --- | --- | --- |
| `data/EpubRepository.ets` | `1c3e006` | 2026-11-18 13:56 |
| `data/mobi/Decompress.ets` | `c606856` | 2026-11-15 13:49 |
| `data/mobi/Kf6Book.ets` | `63ba31b` | 2026-11-15 16:03 |
| `data/BookRepository.ets` | `d8e22e6` | 2026-11-20 16:02 |
| `data/TxtTocRuleRepository.ets` | `f920bf6` | 2026-11-03 11:43 |
| `data/PdfRepository.ets` | `32a055f` | 2026-11-16 15:42 |

`data/BookRepository.ets` 是最晚的一个（11-20 16:02），仍在设备安装时刻（17:39）之前，所以设备上跑的就是这些实现的当前版本。工作区 `entry/src/main/ets` 相对 HEAD 无未提交改动（`git status --porcelain entry/src` 为空）。本轮没有重新构建、也没有重装应用——验证跑的是 11-20 17:39 装的那一版。

### 1. `TXT-READER.md:500` EPUB 正文三处净化 —— 已接

74 本真 EPUB 里没有可见对照：

| 检查项 | 真书命中 |
| --- | --- |
| 非封面章 `body` 内有 `<title>` 元素 | **0 本** |
| 非封面章 `display:none` 块内有可见文字 | **0 本** |
| 非封面章 `cover.jpeg` 出现 >1 次 | **0 本** |

因此构造样本 `净化验证.epub`（`ch1.xhtml` 同时放 `<title>`、带文字的 `display:none` 块、两张 `cover.jpeg`），上机导入后读 `books/local-2ecf14e07ab92b01.txt`：

```text
第一章 净化探针

正文第一段：这一段是真正的正文，必须留下。

正文第二段：封面图重复测试开始。

[[EPUB_IMAGE:file:///…/epub-assets/local-2ecf14e07ab92b01/0.img]]第一张封面图之后。

第二张重复封面图应当被跳过。

正文第三段：重复封面图测试结束。
```

**三处净化全部生效**：`<title>` 里的文字不在、`display:none` 里的文字不在、第二张 `cover.jpeg` 只留一个 `[[EPUB_IMAGE:]]` 标记。判 **已接**。

### 2. `TXT-READER.md:504` SVG `<image>` 转 `<img>` —— 已接

同一样本第二章 `ch2.xhtml` 放 `<svg><image xlink:href="images/pic.png"/></svg>`，导入后正文出现

```text
SVG 图片之前。

[[EPUB_IMAGE:file:///…/epub-assets/local-2ecf14e07ab92b01/1.img]]

SVG 图片之后。
```

图片文件 `1.img` 真的落盘，正文首尾文字完整。判 **已接**。

### 3. `TXT-READER.md:551` MOBI 分卷 `isVolume` —— 已接

4 本真 MOBI 的 NCX 里 `firstChild` 全是 `-1`（无卷），所以构造 `volume-probe.mobi`：以 `pg1342.mobi` 为壳，自写 INDX 头 / TAGX 控制表 / IDXT 偏移表 / CNCX 字符串表，标签 21 = `parent`、22 = `firstChild` 表达卷层级。上机导入后查 `chapters` 表：

```text
idx=0 title=第一卷 卷首    isVolume=1 tocLevel=0
idx=1 title=第一章 开端    isVolume=0 tocLevel=1
idx=2 title=第二章 发展    isVolume=0 tocLevel=1
idx=3 title=第三章 收尾    isVolume=0 tocLevel=1
```

判 **已接**。

### 4. `TXT-READER.md:557` Huff/CDIC 解压 —— 已接

真书全是 `compression=0x0002`（PalmDOC），**没有一本 `0x4448`**（Huff/CDIC）。构造 `huffcdic-probe.mobi`：改 `record0` 的 `compression` 为 `0x4448`、`numTextRecords` 为 1，追加两条记录——`HUFF`（256 项 `table1` 全置 `codelen=1`，加 `mincode`/`maxcode` 表）与 `CDIC`（2 条字典项）。位流 `f0f0` 表示「字典项 0 ×4、字典项 1 ×4」重复两轮。

先用 Python 按 `Decompress.ets:93 HuffcdicDecompressor` 逐行镜像，确认能解出预期正文；再上机导入，读 `books/local-f4be560e038b6b93.txt`：

```text
分段_1

第一章 HUFF 探针：这条正文由 HUFFCDIC 字典第 0 项解出。  ×4
第二章 HUFF 探针：这条正文由 HUFFCDIC 字典第 1 项解出。  ×4
第一章 HUFF 探针：这条正文由 HUFFCDIC 字典第 0 项解出。  ×4
第二章 HUFF 探针：这条正文由 HUFFCDIC 字典第 1 项解出。  ×4
```

`grep -c HUFF 探针` = **16**，与位流预期完全一致，无乱码无缺段。判 **已接**。

### 5. PDF 六条（`TXT-READER.md:526`–`:531`）—— 代码全落地，模拟器验不了正题

已验的部分：选 `sample-30p.pdf` 走导入，屏幕上**给可读提示、应用不崩**；查库 `format = pdf` 的书 **0 本**，`files/pdf-pages/`、`files/pdf-import/` 目录**都不存在** → **书架没落半截书**。

验不了的部分与证据：

| 证据 | 结果 |
| --- | --- |
| `@hms.officeservice.pdfservice.d.ts:21` `System capability: SystemCapability.OfficeService.PDFService.Core` | SDK 声明存在 |
| `sdk/default/hms/ets/api/device-define/phone-hmos.json` 等 | 该 syscap 都有 |
| `hdc shell grep -o OfficeService /system/etc/syscap.json` | **零命中** |
| 对照组 `grep -o Web.Webview.Core` | 能命中（不是 grep 方法问题） |

→ 是**模拟器缺 PDFKit**，不是平台缺。`PdfRepository.ets:23` 已有 `canIUse(SystemCapability.OfficeService.PDFService.Core)` 前置判断，缺能力时抛可读错误。判 **代码已落地·缺真机验证**。

### 6. 本轮明确没做的事

- **没改任何 `.md` 对照表**：155 条里那 4 条已接的，`docs/parity/TXT-READER.md:500` / `:504` / `:551` / `:557` 状态列**仍写着 `未接`**。本文只登记证据，改表要用户点头后单独一批做。
- **没验 `TXT-READER.md:352` / `:436` 两条**：表作者自己写了「待验收方判定」，需要目录页分卷倒序的屏幕截图与滚动模式跨页选区的实际操作，本轮没做。
- **没逐条复核「J 缺前置模块」与「L 纯本地功能未做」里的每条代码引用**：这两类共 69 条，分类依据是原表的差异说明与备注原文，没有对每一条重新跑 `grep` 找实现。
- **没动书源 37 条**：只确认书源引擎与 `OnlineBookService` 存在，没验证每条书源能力的具体消费方接线状态。

---

## 四、建议的批次顺序

| 顺序 | 做什么 | 覆盖条数 | 理由 |
| --- | --- | --- | --- |
| 1 | 把本轮验过的 4 条改表 | 4 | 零成本，改状态列即可 |
| 2 | E 类 20 条重新分派到下列各批 | 20 | 它们本就不该记「不接」，先归位再排期 |
| 3 | `L 纯本地功能未做`（平台支持、缺入口） | 55 | 纯前端接线，无外部阻塞 |
| 4 | 书源界面批（消费方接线） | 37 | 引擎已落地，收益最大 |
| 5 | 前置模块（排版引擎 / 章节缓存 / 正文编辑器） | 14 | 打通后 J 类成片落地 |
| 6 | 朗读 / TTS 批 | 7 | 已纳入范围 |
| 7 | 真机验 PDF | 6 | 只需一台真机 |
| 8 | 数据层（表 / 字段） | 4 | 建表 + 写入方 |
| 9 | 补 `TXT-READER.md:352` / `:436` 取证 | 2 | 只需截图 |
| 10 | AI 在线服务 | 2 | 要改范围决策 |
| 11 | rar / 7z 决策 | 1 | 要决定自研还是引三方 |
| — | 平台无能力，不做 | 3 | Monet / 双引擎 / intent-effect |
| | **合计** | **155** | |
