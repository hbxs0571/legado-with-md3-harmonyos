# 在线书源 12 批交付报告（2026-11-20）

本仓在线书源按 12 批（P0 准入 + P1–P10 实现 + P11 收尾）完成。上游是 legado-with-MD3（Kotlin），本地移植是 legado-with-md3-harmonyos（ArkTS / ArkUI）。路线是复用社区规则引擎 `@legado/sourceengine`（含 quickjs），不自研规则解析与 JS 执行。

## 一、逐批提交号

| 批次 | 提交 | 内容 |
| --- | --- | --- |
| P0 | 无提交（纯验证，不改本仓） | 三轮引擎准入验收，报告 `N:/HarmonyProjects/tmp/booksource-p0-report.md`、`p0bis-report.md`、`p0ter-report.md` |
| P1 | `f9c1292` | 引擎接入（复制 `third_party/harmony-book-source-engine/`，带 URL 修复）+ `LegadoSourceMapper` + 运行时持久化注入 |
| P2 | `4fca9c2` | 单源执行链四步调度器（search / info / toc / content） |
| P3 | `1479361` | 多源并发搜索 + `SearchResultMerger` 四桶归并 + 搜索页在线结果 |
| P3-E | `ce59314` | 在线书入书架 + 在线正文链（缓存优先 + 网络兜底，对齐上游 `BookHelp.getContent`） |
| P4 | `69812c5` | 书源管理页列表与条目操作（904 条 / 搜索 / 筛选 / 7 排序 / 域名分组 / 11 批量 / 拖拽） |
| P5 | `4394c9b` | 书源编辑页（六 tab / 68 字段槽 / 整条 sourceJson 读写 / 9 项菜单） |
| P6 | `07502ff` | 书源导入导出三路（本地文件 / 在线 URL / 整表导出；扫码平台无 API，真实提示） |
| P7 | `4824a7e` | 发现页接入真实发现链（exploreUrl 四写法解析 / 分类 chip / 分页 / 点书入架） |
| P8 | `d8e22e6` | 换源（候选搜索 / 目录校验 / Jaccard 进度迁移 / 单事务落库） |
| P9 | `02d00c0` | 书源登录与 WebView（ArkWeb 宿主 / 表单+Web 双模式 / cookie+header+info 三载体回写） |
| P10 | `f604397` | 书源调试页（五类目标 / 日志总线 / 四档过滤 + 详情 / 两处入口） |
| P11 | 本批（文档收尾，无代码） | 七文档更新 / 七表 1 行回填 / KI-BS1–BS6 登记 / 三件套复跑 / 本报告 |

P0–P10 均为独立提交，无跨批合并。各批之间夹杂他人并发的 docs / 主题相关提交，未纳入本模块提交，也未改动其工作区内容。

## 二、P0 三轮准入数据

准入样本来自 904 条真实书源（`N:/HarmonyProjects/测试/backup.zip` 的 `bookSource.json`），分层抽样、挂 ArkWeb 运行时、按引擎 `decide()` 真实分流。

| 轮次 | 关键做法 | 数据 |
| --- | --- | --- |
| P0 | 读 yck1331.json 前 30 条，未挂 ArkWeb，脚本走轻量解释器 | ok 4/30 = 13.3%；五类分布 ok4 / empty6 / rule-fail1 / js-fail8 / net-fail11 |
| P0-bis | 换 904 真实库、分层抽样（A/B/C）、挂两个 Web 运行时 | p_A 13/30 = 43.3% [25.6–61.1]；p_B 8/15 = 53.3%；p_C 1/15 = 6.7%；p_all 加权 43.3% |
| P0-ter | 修引擎 URL 拼接缺陷 + A 层拆四象限 + 样本翻倍 131 | A1 30/50 = 60.0% [46.4–73.6]；A2 6/10 = 60.0%；A3 0/10；A4 0/11；p_A 44.4%；p_B 56.0%；p_C 4.0%；p_all 44.6% |

**结论**：整体 p_all 44.6% 未过 50% 硬线，按判据交回数据、不擅自改计划；A1（纯 URL、无 `{{}}` 代码模板、无 `java.`、无 loginUrl）与 A2（带 `#` 锚点）各 60% 达「可按只支持 A1/A2 立项」门槛。故实现范围收敛为 A1/A2，A3/A4/C 列为显式缺口。

**带入实现的引擎修复**：`AnalyzeUrl.cleanBaseUrl` 改法 A——先截 `##`、再截单个 `#`、末尾 `.trim()`，修复 base URL 带 `#` 时相对路径拼接错误。P0-ter 对照 60 条 +2 ok、0 变坏。改法 B（不委托 `BookUrlResolver.resolve`）经评估 904 库现实影响 0，未做。

## 三、跑通的真实书源与场景

上机环境：模拟器 127.0.0.1:5555，深色模式。

- **单源四步链（P2）**：3/6 源全过——77读书网（正文 772 字）、鸟书网（1674 字）、元尊阁（2413 字）。其余 3 源失败属源自身规则空 / 超时 / 书名规则未命中。
- **多源搜索（P3）**：36 源 19–22 秒返回 568–582 结果，193–195 条多源命中；TOP1《剑来》17 源命中排第一。
- **在线正文链（P3-E）**：搜「剑来」→ 77读书网在线目录 1362 章（首章「新书感言」）→ 正文 770 字，打开能读；在线 Book 落库往返 origin/tocUrl/originName/kind/isLocal 全对。
- **管理页（P4）**：真实界面 904 条列表、搜索「笔趣阁」收敛 7 条、分组筛选、七种排序、长按多选、11 项批量操作、条目菜单 7 项（登录项因无 loginUrl 正确隐藏）。
- **调试页（P10）**：填「我的」示例开始调试，产出「过程」「错误」两条带耗时与时间戳的日志；点「错误」过滤从 2 条收敛到 1 条；点日志卡片弹出详情浮层。截图 `N:/HarmonyProjects/tmp/p10detail.jpeg`。

## 四、已知问题（KI-BS1–BS6）

详细条目见[已知问题](../KNOWN-ISSUES.md#在线书源实现批p0p11r352遗留的已知问题)。摘要：

1. **KI-BS1** 段评/书评规则（ruleReview）整块缺——引擎无 `ReviewRule` 类。
2. **KI-BS2** 十个规则字段映射丢失（checkKeyWord / canReName / downloadUrls / relatedBooks / preUpdateJs / formatJs / isVolume / subContent / webJs / callBackJs），原 `sourceJson` 完整保留只是引擎侧不用。
3. **KI-BS3** coverDecodeJs 与 exploreScreen 缺——引擎挪到原生书源定义，本工程走兼容书源路径。
4. **KI-BS4** `java.*` 桥 32 方法未支持，影响 107 源（11.8%），是 A3/A4/C 通过率低的主因；`getElements`/`connect` 可能有替代但未验证。
5. **KI-BS5** 书源校验（单条 / 批量 / 六项设置）整块未做，批量面板「校验书源」按钮无真实执行链。
6. **KI-BS6** 首页模块（homepageModules）不做。

## 五、未验证清单（诚实口径）

以下项**没有**上机验证通过，不记作「已验证」。2026-11-20 追加一次模拟器上机复核后的最新口径：

- 真机（非模拟器）联网抓取：所有书源抓取在模拟器完成，真机网络 / DNS / TLS 环境未单独验收（本轮无真机可用；模拟器侧 ping `www.77shuku.info` 通，178.107.155.19 / 177ms / 0% 丢包，仅证明模拟器网络可用）。
- 登录凭据端到端：P9 登录做了离线解析自测（904 库 111 登录源表单解析 24/24）与页面不崩溃验证，但「输入账号密码→提交→后续搜索带登录态」的完整真机链路未跑通（本轮仍无可用账号凭据）。
- 换源落库后的跨会话进度迁移：P8 进度算法有六例离线自测；本轮再次代码层复核确认 `newIndex → chapterIndex / chapterProgress / lastChapter / progress` 写入并经 `BookRepository.changeSourceBook` 单事务落库（`Index.ets:6884-6923`）。但设备书库为 P4 导入的 904 条残缺源、无可用换源候选，端到端（换源后杀进程重进、进度保持）仍未上机。
- P10 调试页详情浮层已在模拟器补证；本轮补跑「详情」目标：产出起始 Message 打点（`+0.001s`、按 kind 上色 + 时间戳正常），但书源「番茄聚合API」与 77shuku URL 规则不匹配 + 网络 hang，抓取约 3 分钟无终态日志。详情 / 目录 / 正文三类目标的完整打点输出仍未逐一跑通（仅搜索目标此前完整跑通）。
- 批量操作 11 项：本轮复核「校验书源」确为占位（`ProfileSubPages.ets:593` 仅 `onUnavailableAction`），无执行链（KI-BS5 登记正确）；「导出」落盘路径为系统文件选择器，UI 自动化难验；「置顶 / 加分组」落库结果仅 UI 层验证。**「置底」本轮升级为已验证**：置底后 `aa force-stop` 重进，首行仍为置底目标源（番茄小说聚合API），order 持久化通过。
- A3 / A4 / C 类脚本源与代码模板规则不承诺，未做通过率验收（P0 三轮已否定，范围收敛为 A1 / A2 纯 URL 源）。

## 六、验证手段与产物位置

- 逐条原始数据与分析脚本在 `N:/HarmonyProjects/tmp/`：`p0ter-results.json`、`p0ter-full.log`、`p0ter-sample.json`、`p0ter_analyze.py`、`p0ter_urltest.py`、`p7_parse_test.js`、`p8_progress_test.js`、`p9_login_test.py`、`p10_logic_test.py`。
- 上机截图在 `N:/HarmonyProjects/tmp/`：`p10detail.jpeg`（调试详情浮层）、`dbg3.jpeg` / `dbg4.jpeg`（调试页）、`dbg-filter.jpeg`（过滤生效）、`p4real.jpeg`（管理页）等。
- 2026-11-20 追加复核：批量「置底」跨会话持久化、KI-BS5 占位代码、换源进度迁移写入链均经模拟器 / 代码层确认；模拟器网络连通性经 `ping` 确认；证据为上机 dump 与源码行核对，未新增独立截图文件。
- 构建产物 `entry/build/default/outputs/default/entry-default-unsigned.hap` 属构建输出，未纳入提交。
