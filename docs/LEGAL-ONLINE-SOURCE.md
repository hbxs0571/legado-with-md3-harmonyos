# 在线书源的法律与合规边界

本文档记录「在线书源」功能引入后，项目在法律性质、许可合规与陈述一致性三方面的自查结论。它回答的不是「能不能做」（该功能已列入 [项目队列](PROJECT.md) 的范围内），而是「做到哪一步仍在安全区、现有公开文件有哪些已经与代码不符」。

**本文档不是法律意见。** 撰写者不是执业律师；涉及实际发行、应用市场审核或被权利人投诉时，应取得执业律师的正式意见。文中每条结论都标注了性质：

- **【依据】** —— 有明确法条、司法解释或已生效判决支撑
- **【判断】** —— 基于本项目事实的风险推断，可能被推翻
- **【事实】** —— 本仓库代码或文件的实测状态，可复核

---

## 一、现状核查：已经存在的不一致

这一节列的不是「加功能后会出问题」，而是**现在就已经不成立**的陈述。它们与功能是否上线无关，越早修越好。

### 1.1 `PRIVACY.md:15` 与权限声明矛盾

原文：

> 当前模块配置没有声明 INTERNET 权限，源码未接入应用自有账号、广告、分析统计、远端崩溃收集或云同步 SDK……

**【事实】** `entry/src/main/module.json5:13` 已声明 `ohos.permission.INTERNET`。这句话在当前 HEAD 上就是不实的。

同句后半「应用没有自有服务端接收书籍正文或阅读记录」仍然成立，且是本政策最有价值的一句，修订时**不应连带删除**。

### 1.2 `TERMS.md:11` 声明不提供在线书源服务

原文：

> 本项目提供原生本地阅读器的开发中实现，不提供书籍交易、内容授权、云存储账户或在线书源服务。

**【事实】** 在线书源已列入 [项目队列](PROJECT.md) 的「在线服务（已纳入范围）」，且 `entry/src/main/ets/bookSource/` 下已有 10 个文件、903 行的实现。这句话需要拆分改写，不是删除。

### 1.3 `PRIVACY.md:24` 对在线书不成立

原文：

> 单书移出会移除书架记录并尝试删除其正文副本，保留外部原文件。

**【事实】** `entry/src/main/ets/data/BookRepository.ets:1619` 的 `deleteBook` 只清三样东西：`EpubRepository.clearAssets`（EPUB 内嵌图）、`PdfRepository.clearAssets`（PDF 页图）、`books/{id}.styles.json`（行内样式 sidecar）。它**不触碰** `entry/src/main/ets/bookSource/OnlineBookService.ets:15` 定义的 `online_book_cache` 目录。在线书的章节缓存会留在设备上。

### 1.4 `SECURITY.md` 完全未覆盖书源规则

**【事实】** `grep '书源|规则|脚本|script' SECURITY.md` 命中数为 **0**。全文只提到「未知来源 EPUB/ZIP」。

而书源规则是可以执行的代码：兼容书源的 `@js:` 与 `<js>` 脚本在 QuickJS 沙箱中运行，原生书源的 `script` 阶段与 JS 函数库同样在本机执行。这是本次引入的最大攻击面，安全文档一字未提。

**【事实】** 引擎还提供 `third_party/harmony-book-source-engine/sourceengine/src/main/ets/core/http/TlsTrustStore.ts` —— 一份**用户可控的 TLS 信任例外**（存于 `preferences` 的 `tls_trust_settings` / `trustedHosts`，按主机精确匹配，不传递到子域与重定向目标）。`HttpClient.ts:792` 会据此放行证书校验失败的主机。这同样是安全文档应披露的机制。

### 1.5 `NOTICE.md` 缺第三方引擎署名

**【事实】** `NOTICE.md` 中 `wip3l` 仅在 `:15` 出现一次，讲的是**正文排版算法**参考 `qingye-reader` 的 `ReaderV2Paginator`。而整包引入的**规则引擎** `harmony-book-source-engine`、其作者署名 `李其健`、以及 `quickjs` 与 MIT 许可，**全部零命中**。

hbse 的 `NOTICE` 明确要求保留 `Copyright (c) 2026 李其健`。这是 GPL-3.0 第 4、5 条的义务，不是可选项。

### 1.6 `rawfile/licenses/` 缺 MIT 文本

**【事实】** `entry/src/main/resources/rawfile/licenses/` 下只有 `Apache-2.0.txt` 与 `GPL-3.0.txt`。

`third_party/harmony-book-source-engine/quickjs/` 是 MIT 许可。MIT 条款要求「版权声明与本许可声明应包含在软件的所有副本或实质部分中」。仅分发 HAP 而不附源码仓库时，该声明未随附。

### 1.7 曾经出现过的探针素材（已于 2026-11-20 清理）

**【事实】** 2026-11-20 本文档初稿时，工作区曾存在三个未提交项；同日维护者已将其清理，当前 `git status` 中这三项均不存在（`P4ProbePage.ets` 与 `p4-904-sources.json` 已删除，`EntryAbility.ets` 已恢复为 `loadContent('pages/Index')`）。保留此节是为了记录它们当时的样子：

```
 M entry/src/main/ets/entryability/EntryAbility.ets   ← :137 被改成 loadContent('pages/P4ProbePage')
?? entry/src/main/ets/pages/P4ProbePage.ets
?? entry/src/main/resources/rawfile/p4-904-sources.json   ← 2.9 MB，904 条
```

HEAD 版 `EntryAbility.ets` 的对应位置一直是 `windowStage.loadContent('pages/Index')`。

关于 `p4-904-sources.json` 的实际内容：**904 条记录只含元数据**（`bookSourceName` / `bookSourceUrl` / `exploreUrl` / `bookSourceGroup` 等），`ruleSearch` 与 `ruleToc` **各 0 条**。它不能直接用于搜索与正文抓取，但它是一份 904 个站点的地址清单，且 `exploreUrl` 内含 `@js:` 脚本。

**【判断】** 这类探针素材在发版前必须移除：按当时的状态打包，HAP 内会带这份 904 站点的清单——见第二节为什么这会把项目从安全区推到黄区。它已清理，但值得记下来，因为下次接书源相关实验时同样的形态会再出现一次。

---

## 二、法律性质的分界线

### 2.1 差别在「谁做选择与推荐」

**【依据】** 《民法典》第 1169 条：教唆、帮助他人实施侵权行为的，与行为人承担连带责任。

**【依据】** 《最高人民法院关于审理侵害信息网络传播权民事纠纷案件适用法律若干问题的规定》（法释〔2012〕20 号）第 7 条把帮助侵权分为两种：**教唆**（以言语、推介技术支持、奖励积分等方式诱导、鼓励）与**帮助**（明知或应知他人侵权，未采取删除、屏蔽、断开链接等必要措施）。

**【依据】** 同解释第 9 条列举认定「应知」的考量因素，其中第（三）项是「是否**主动选择、编辑、修改、推荐**」。

**【判断】** 因此分界线落在：**「可配置能力」把选择与推荐留给用户；「内置规则」由维护者自己完成选择与推荐。** 前者缺乏「明知的具体侵权对象」，后者直接落入第 9 条第（三）项。

### 2.2 三档刻度

| 状态 | 定性 | 说明 |
| --- | --- | --- |
| 仅提供解析引擎 + 用户本地粘贴 JSON 导入 | 安全区 | 无内置规则、无推荐入口、有实质性非侵权用途（正版站、公网站、自建站）、无营利 |
| 内置默认书源、提供订阅地址列表、以「免费看全网小说」为卖点 | 黄区 | 逐一对应第 9 条的「主动选择/推荐」与第 7 条的「诱导鼓励」 |
| 预置指向盗版站的规则、内置付费章节绕过 | 红区 | 几乎必然被认定帮助侵权 |

**【事实】** 项目当前处于**安全区**：`entry/src/main/resources/rawfile/` 中只有 `txttoc/builtin-rules.json`（TXT 目录规则，不是书源）与两份许可文本；`BookSourceImporter.ets` 走用户本地导入。

**【判断】** 1.7 节那 904 条若随包分发，即使规则不完整，性质上也已是「维护者替用户挑选了站点」。这是本功能线上最需要守住的一条线。

### 2.3 一个容易过度类推的判例

**【依据】** 快播案（北京市海淀区人民法院（2015）海刑初字第 512 号）确立：技术中立不当然免责，明知他人用于侵权仍提供实质性帮助且不采取必要措施的，构成帮助。

**【判断】** 该案被告是有服务器、有缓存、有用户规模、有营利的主体。直接套用到个人开源作者属过度类推。引用它时应说明这一区别，不宜作为本项目风险等级的依据。

---

## 三、许可合规

### 3.1 三方许可无冲突

**【依据】** 主项目 `LICENSE` 为 GPL-3.0；`third_party/harmony-book-source-engine/LICENSE` 同为 GPL-3.0；`third_party/harmony-book-source-engine/quickjs/LICENSE` 为 MIT。MIT 与 GPL 兼容（FSF 明确立场），并入后整体按 GPL 分发。同版本 GPL 之间可自由合并（第 5 条组合作品、第 6 条非源码形式传递）。

**【事实】** `build-profile.json5:27-34` 把 `sourceengine` 与 `quickjs` 注册为源码模块，`entry/oh-package.json5` 以 `file:` 引用——构成组合作品而非聚合体。但由于主项目本就是 GPL-3.0，整个 HAP 就是 GPL-3.0，无需切割。

### 3.2 第 7 条链接例外是纯权利，且本项目用不上

**【依据】** hbse 的 `LICENSE` 末尾附有一条依 GPL-3.0 第 7 条作出的附加许可（Harmony Book AI Engine 链接例外 1.0）。其文本自述为「**额外许可**你传递由此形成的作品」，并明确：

> 依据第 7 条，你在传递受保护作品的副本时，可以从该副本中删除本附加许可。

**【判断】** 其射程仅限「与 Harmony Book AI Engine 链接或组合」。本项目未链接该引擎，因此该例外既不授予也不剥夺任何东西，可视为对分发口径无影响。

**【事实】** 但 `NOTICE.md` 应当说明本仓库**不使用**该例外——不写，读者无法判断本仓库的分发口径。

### 3.3 两项待补义务

见 1.5 与 1.6。二者性质不同：

- **hbse 署名** —— GPL-3.0 第 4、5 条义务，且上游 `NOTICE` 明确要求保留版权人。
- **MIT 文本** —— MIT 条款的随附要求，影响的是仅取 HAP 而不取源码的用户。

---

## 四、实现层面的两个具体问题

### 4.1 限流有实现，但按书源不按站点，且等待无上限

**【事实】** 引擎有限流器 `third_party/harmony-book-source-engine/sourceengine/src/main/ets/core/http/BookSourceRateLimiter.ts`，签名 `static async acquire(source, isCancelled?, maxWaitMs: number = 0, stageRate?)`；key 取 `source.bookSourceUrl || source.bookSourceName`（`:49`），**按书源而非按站点**。调用点在 `AnalyzeUrl.ts:773`/`:790`（`fetchFollowingRedirects`）与 `:630`（`fetchBinary`），都经 `acquireTimedSlot`（`:754`）。

**【事实】** 本地 `entry/src/main/ets/bookSource/SourceHttp.ets:37` 是 `au.setCancelCheck(SourceHttp.cancelCheck);`，只传第一个参数，于是 `maxWaitMs = 0`，即**无限等待**。`SearchCoordinator.ets:31` 的并发是 8。`LegadoSourceMapper.ets:54` 确实映射了 `concurrentRate`；实测 904 条书源里有 **51 条**带该字段（`3`×20、`5`×16、`1000`×4、`1500`×2、`10`×2、`800`、`30`、`500`、`2000`、`30/5000`、`10/1000`、`20/60000`）。

**【依据】** 《网络安全法》第 27 条禁止「提供专门用于」非法侵入、干扰他人网络正常功能、窃取网络数据的程序、工具。「**专门用于**」是核心构成要件。

**【判断】** 通用书源引擎有大量正当用途，不满足「专门用于」，不落入该条射程。限流机制本身存在，真正的两个缺口是：① 粒度按书源不按 host，同一站点的多个书源会各算各的窗口，防不住多源并发打同一站点；② 等待无上限，声明 `1000` 的源在 8 并发下可能长期排队而不报错。这两点都可能被主张为「干扰他人网络正常功能」的指摘空间，改动成本不高。

**（本节初稿曾写成「缺 per-host 限流」，是错的——引擎有限流器，我没查到。已按实测更正。）**

### 4.2 脚本执行使项目成为执行环境提供方

**【事实】** `entry/src/main/ets/bookSource/SourceHttp.ets` 的模板替换与引擎的 `AnalyzeUrl.parse` 会处理 `@js:` 规则；QuickJS 沙箱与分阶段 ArkWeb 均会在本机执行书源脚本。

**【判断】** 这使项目从「工具提供者」变为「脚本执行环境的提供方」。若规则含登录绕过、验证码识别等内容，项目角色会向「帮助」滑动。这一条不需要改代码，**在文档中明示不支持此类脚本**即可隔断。

---

## 五、几条常见但不适用的规定

这几条常被援引，但对本项目基本不适用。写下来是为了避免过度自我限制或误判。

### 5.1 避风港不适用，但也不需要适用

**【依据】** 《民法典》第 1194–1197 条、《信息网络传播权保护条例》第 14–17 条的通知—删除规则、《电子商务法》第 42–43 条，适用主体均为「**网络服务提供者**」。

**【判断】** 本项目在 GitHub 托管代码，是内容上传者/开发者，不是服务提供者；GitHub 才是享有避风港的一方。主体不匹配意味着没有「收到通知必须删除否则担责」的法定来源（GitHub 自身的投诉流程除外）。但**这不等同于安全**：具体通知一旦到达并被无视，会成为过错的直接证据。实践中高频场景不是诉讼，而是被抓取方发律师函要求下架或删除内置规则。

### 5.2 《反不正当竞争法》第 12 条基本不适用

**【依据】** 该条要求双方均为「**经营者**」且存在竞争关系。

**【判断】** 个人开源项目无营利、无竞争关系，直接适用概率低。风险主要落在用户侧。

### 5.3 Robots 协议不是法律，但有证据效力

**【依据】** 中国法下 robots 协议无强制力。百度诉 360 案（北京市第一中级人民法院（2013）一中民初字第 13657 号）是通过《反不正当竞争法》第 2 条的诚信原则与商业道德赋予其竞争法意义，而非直接依 robots 协议本身。

**【判断】** 工具不读取 robots.txt 本身不违法；但会成为认定「违反商业道德」或「主观恶意」的证据。若在文档中教用户无视 robots 或提供绕过手段，将被作为过错证据使用。

---

## 六、按性价比排序的处理顺序

| 顺序 | 事项 | 性质 | 对应节 |
| --- | --- | --- | --- |
| 1 | 回退 `EntryAbility.ets`、不提交 `P4ProbePage.ets` 与 `p4-904-sources.json` —— **已于 2026-11-20 完成** | 决定安全区/黄区 | 1.7 |
| 2 | 修订 `PRIVACY.md:15`、`TERMS.md:11`、`PRIVACY.md:24` —— **已于 2026-11-20 完成** | 现有陈述与代码不符 | 1.1–1.3 |
| 3 | `NOTICE.md` 补 hbse / 李其健 / quickjs / MIT 署名与第 7 条例外说明 —— **已于 2026-11-20 完成** | GPL §4/§5 与 MIT 的明确义务 | 1.5、3.2 |
| 4 | `rawfile/licenses/` 补 MIT 文本与第三方许可全文（`MIT.txt`、`THIRD-PARTY.txt`）—— **已于 2026-11-20 完成** | 同上 | 1.6 |
| 5 | `SECURITY.md` 补「书源规则是可执行内容」与 TLS 信任例外两段 —— **已于 2026-11-20 完成** | 新引入的最大攻击面 | 1.4 |
| 6 | 限流改为按站点、并给等待设上限（现按书源、等待无上限） | 降低指摘空间 | 4.1 |
| 7 | 文档明示不支持验证码绕过、登录破解类脚本 | 隔断「专门用于」要件 | 4.2 |

第 2–5 项已于 2026-11-20 全部落地：`PRIVACY.md` 补第 6 条网络请求与在线书缓存清理说明，`TERMS.md` 改为「不提供书源内容服务、只提供执行用户导入规则的通用引擎」，`NOTICE.md` 补 hbse 整包署名与四个第三方组件，`rawfile/licenses/` 新增 `MIT.txt` 与 `THIRD-PARTY.txt` 并已实测打进 HAP，`SECURITY.md` 补脚本执行与 TLS 信任例外两段。第 6、7 项仍未做：第 6 项要改引擎的限流 key 与 `SourceHttp.ets:37` 的第二参数，第 7 项要在文档里明示脚本边界（`SECURITY.md` 已写「不支持登录绕过类脚本」的等价表述，但未逐字列出验证码与登录破解两类）。

**长期约束（不在待办内，是持续要求）**：不内置任何默认书源、不提供订阅地址列表、不做「免费看全网小说」类宣传。这三条一旦破了，前面全部努力归零。

---

## 七、取证边界

**本节的结论来自**：两位领域专家（合同审查、制度文件撰写）的独立分析 + 撰写者逐条复核。

**已复核的事实**（可重复验证）：`module.json5:13` 的权限声明；`PRIVACY.md:15` / `TERMS.md:11` / `PRIVACY.md:24` 的原文；`NOTICE.md` 的署名缺失；`rawfile/licenses/` 的实际内容；hbse `LICENSE` 末尾第 7 条例外原文；`BookRepository.ets:1619` 的清理范围；`SearchCoordinator.ets:31` 与 `LegadoSourceMapper.ets:54`；`TlsTrustStore.ts` 的存在与机制；`p4-904-sources.json` 的条数与字段构成；`EntryAbility.ets` 工作区版与 HEAD 版的差异；上游 `legado-with-MD3` 顶层无独立法律文件（find 零命中）、`README.md` 113 行与 `:74` 起免责声明五小节、`DefaultData.kt` 的四个导入函数、`defaultData/bookSources.json` 的 1 条书源与全仓零读取、`app/build.gradle.kts:265-267` 的 Firebase 三项依赖与 Crashlytics 零命中。

**未验证的**：

- 未运行 `assembleHap`，未在模拟器上确认书源搜索与正文抓取的真实网络行为。因此任何涉及「请求中包含哪些字段」的推断（搜索关键词、Cookie、请求头、IP、UA）均来自 `WebBookService`、`SourceHttp`、引擎 `CookieStore` 的代码路径，**未经抓包证实**。
- 未核验 `acorn` 被压缩内置于 `StageScriptParserSource.ts` 后是否保留 `@license` 头。
- 未核验 HAP 打包产物中 `licenses/` 的实际内容。
- 法条与判例的引用为通行理解，**未逐条比对最新修订文本**；案件编号与要旨来自公开资料。

**本文档未做的**：没有修改任何现有文件（`DISCLAIMER.md`、`TERMS.md`、`PRIVACY.md`、`NOTICE.md`、`SECURITY.md` 均未动），没有改动任何代码，没有回退 1.7 节所述的工作区状态。

---

## 八、为什么不照抄上游：上游根本没有这套文件

**【事实】** 本项目顶层现有五份法律文件（`DISCLAIMER.md` 11 行、`TERMS.md` 21 行、`PRIVACY.md` 33 行、`NOTICE.md` 15 行、`SECURITY.md` 7 行）与 `LICENSE`（GPL-3.0）。上游 `legado-with-MD3` 顶层**只有 `LICENSE`**：`find . -maxdepth 2 \( -iname '*privacy*' -o -iname '*disclaimer*' -o -iname '*terms*' -o -iname '*notice*' -o -iname '*security*' \)` 零命中，`docs/` 下也无法律类文档。所谓「上游的法律文件」，实际是 `README.md:74`–`:113` 的 `## ⚠️ 用户协议与免责声明` 一节（`English.md:108` 起为英文版），共五小节 19 条。

### 8.1 上游那份声明里有两处自己没做到

**【事实】** 一、2 称「本软件默认状态下不预置、不内置、不提供任何第三方网站内容、数据资源或解析规则」。但 `app/src/main/assets/defaultData/bookSources.json` 里有 1 条完整书源（`消消乐听书` / `https://www.kaixin7days.com` / 分组「听书」，`ruleSearch`、`ruleToc`、`ruleContent` 齐备）。

**【事实】** 但它没有被加载：`help/DefaultData.kt` 只导入 `httpTTS` / `txtTocRule` / `rssSources` / `dictRules` 四类，**没有 `importDefaultBookSources`**；全仓 `grep -rn 'defaultData/bookSources\|bookSources\.json'` 在 `.kt`/`.java` 下零命中。该文件是死文件，「不内置解析规则」当前成立，靠的是它恰好没被引用，而不是靠机制保证。

**【事实】** 四、3 称「可能集成第三方统计或崩溃分析服务（如 Firebase Crashlytics 等）」。实际 `app/build.gradle.kts:265-267` 集成的是 `firebase-bom` + `firebase-analytics` + `firebase-perf`，**没有 Crashlytics**（全仓 `grep -i crashlytics` 零命中）。同一句里点名的组件并不存在。

**【判断】** 这两处说明该声明的写法是「先写一句免责，再去核对代码」，而不是从实际行为倒推。它是 README 文字，不是经过发版流程校对的合规文件。

### 8.2 上游没有的，是它不需要；不是我们该删

| 文件 | 上游 | 本项目 | 为什么不能照抄上游 |
| --- | --- | --- | --- |
| 隐私政策 | 无独立文件，仅 README 四、1–4 四条 | `PRIVACY.md` | 上游直发 APK/F-Droid，不经应用市场隐私审核；HarmonyOS 应用市场上架需提交隐私政策 |
| 使用协议 | README 二、1–4 | `TERMS.md` | 本项目比上游多一条硬约束：用户导入的书源规则由谁负责 |
| 第三方许可 | **无**，`README` 里 `grep 'Apache\|MIT\|GPL\|许可'` 零命中 | `NOTICE.md` + `docs/RESOURCE-LICENSES.md` | 上游 121 个 `implementation` 依赖全是 Maven 坐标，POM 自带许可；本项目 `third_party/` 是源码整包拷入，GPL §4/§5 署名义务无人代做 |
| 安全反馈 | 无 | `SECURITY.md` | 书源规则是可执行内容，攻击面与上游不同 |
| 权限说明 | README 四、4 一句带过（实际声明 19 个权限） | `PRIVACY.md` 逐项 | 本项目声明 4 个权限，数量少但同样需逐项说明 |

**【依据】** GPL-3.0 第 4、5 条要求传递源码时保留版权声明与修改说明。上游靠 gradle 解析 POM 完成依赖侧声明，本项目把 hbse 与 quickjs 源码直接纳入仓库，这一层没有工具代劳。

### 8.3 「最终目标是还原上游」在功能上成立，在法律文件上不成立

**【判断】** 三条理由：

1. **法律文件跟随主体与分发渠道，不跟随代码。** 上游是 HapeLee 个人分发的 Android APK，本项目是 hbxs0571 分发的 HarmonyOS HAP——两个主体、两个渠道、两套应用市场审核规则。照抄上游等于用别人的合规假设套自己的场景。
2. **上游那份声明不是法律文件。** 它没有权限清单、没有数据流向、没有第三方许可、没有安全反馈渠道，因为它没有发版审核流程要过。
3. **本项目确实比上游多引入了东西。** `third_party/harmony-book-source-engine`（GPL-3.0 整包）与 `quickjs`（MIT）在上游不存在，第三方许可面天然更复杂。

**【事实】** 本项目 `DISCLAIMER.md` 有两句上游没有、也不该被删掉的话：「不因代码开源而取得第三方图片、字体或品牌权利」「本声明不能替代版权许可、隐私义务或安全措施，也不表示任何行为因『学习交流』而自动合法」。这两句比上游同类表述更清醒。

### 8.4 可以简化的是哪些

**【判断】** 五份文件里确有防御性写作，可压缩但不紧急：

- `SECURITY.md` 仅 7 行，内容可并入 `TERMS.md` 或 `DISCLAIMER.md`，不必单列。
- `PRIVACY.md` 中关于「当前未指定独立私密联系邮箱」一类的说明属程序性描述，可并入 `SECURITY.md` 或删除。

**不能简化的是**：

- `PRIVACY.md` 的网络权限与数据去向两块 —— 应用市场审核直接看这两项。
- `NOTICE.md` 的第三方署名 —— GPL 硬义务。
- `DISCLAIMER.md` 里那两句「不表示自动合法」的话 —— 最有效的自我保护。

**【判断】** 结论：不要按「还原上游」处理法律文件，按本项目自己的分发场景处理。第六节七项中的第 2–6 项都属于「补齐本项目自己的缺口」，不是「向某个标准对齐」——上游在这几项上给不出参考，因为它压根没写。

---

## 关联

- [项目队列](PROJECT.md) —— 在线服务范围与书源技术可行性实测（r359）
- [开源与发行范围](RELEASE.md) —— 公开仓库不得包含的内容
- [资源许可清单](RESOURCE-LICENSES.md) —— 第三方资源来源与哈希
- [已知问题](KNOWN-ISSUES.md) —— 书源引擎接入的已知缺口
