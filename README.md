# Legado with MD3 for HarmonyOS

使用 ArkTS / ArkUI / Stage 开发的 HarmonyOS 原生阅读器，社区独立移植自 [Legado with MD3](https://github.com/HapeLee/legado-with-MD3)，上游阅读项目为 [Legado](https://github.com/gedoor/legado)。本项目不代表上游、华为或 Google 官方，不表示获得其背书。

**当前是开发预览源码，尚未完成全部迁移与验收，不是成熟稳定版。当前不提供经过发行签名和安装验证的安装包。**

## 当前进度（2026-10-28 E 端整合源码基线）

| 范围 | 已有能力 | 尚未完成 / 限制 |
| --- | --- | --- |
| UI 与导航 | 首页、书架、发现、订阅、我的及多个设置/直接目的页；阅读器顶栏/底栏各含 28 项动作池，订阅源管理独立页已实现 | 阅读器、阅读设置、目录、书内搜索和朗读设置五路由仍在实现中；整体验收未完成，部分按钮只提示“未迁移” |
| 本地阅读 | TXT/EPUB、本地书架、目录、阅读进度、书架 v12 元数据、眼保设置、书签、正文处理与按书规则 | E 端构建/覆盖安装后仅核到替换净化空列表；未在 E 创建规则或完成文件/ZIP 往返。TTS 未接入，复杂 EPUB 排版和章节图片仍有限 |
| 源码与许可 | 此仓库整理当前源码、构建配置、许可、隐私与使用说明 | 公开源码不代表相关功能已全部完成；正式签名安装包与应用市场上架未交付 |
| Android ZIP | Android ZIP 导入预览、受支持书目/进度/设置恢复、分类过滤和再导出、缺正文书目提示；规则 JSON 映射已接入源码 | 未映射类别仍只归档；E 端替换规则 ZIP 往返尚未验证；无全类别事务回滚、完整 Android 数据库语义或跨设备加密凭据兼容保证 |
| 在线业务 | 界面或备份归档中可能出现对应入口与数据 | 在线书源执行、在线搜索、RSS 拉取、TTS、AI、WebDAV、云同步和 Web 服务尚未接入 |

备份 ZIP 不包含书籍正文；请另行保管原始 TXT/EPUB。备份可能带有原 Android 数据中的账号信息、Cookie、请求头或令牌，**不要把个人备份上传到 Issues 或公开仓库**。

截至当前快照，资源清单核对了 133 个 SVG，其中 50 个与 Android drawable 路径精确一致，39 个 SVG 有 AndroidX Material / Apache-2.0 来源记录；此前待核的 10 个新增图标现已追溯到原 AndroidX 调用或原有箭头资源。详见[资源清单](docs/RESOURCE-LICENSES.md)。

本次公开基线的脱敏进度、模块验收和剩余风险见[当前进度](docs/PROGRESS.md)、[模块状态](docs/MODULE-STATUS.md)与[已知问题](docs/KNOWN-ISSUES.md)，不包含本机路径、用户书目、阅读位置或设备诊断资料。

## 获取与构建

本仓库根目录就是 HarmonyOS 工程，不需要父目录 Android 工程即可构建。请阅读 [构建说明](docs/BUILDING.md) 和 [验证记录](docs/VALIDATION.md)。

机器无关的功能队列、页面模块、阅读行为、Android ZIP 兼容、资源范围和验收口径见[开发文档索引](docs/INDEX.md)。本仓库不包含本机续接记录、历史诊断材料或用户测试数据。

- 配置兼容/目标版本：`5.0.0(12)`；这不是 API 12 真机兼容性证明。
- 历史开发环境：DevEco Studio 26.0.0.851 / SDK 26；历史设备记录为 OpenHarmony 7 / API 26 模拟器。
- 应用内部版本：`0.1.0`，versionCode `1000000`，bundleName `io.legado.harmony`。内部名称与版本沿用开发工程，尚未作为稳定升级契约。

## 隐私、使用与许可

- [隐私政策](PRIVACY.md)：实际处理的数据、备份风险、存储与删除方式。
- [使用协议](TERMS.md)：开发预览的使用说明，开源许可优先，不额外限制 GPL 权利。
- [免责声明](DISCLAIMER.md)：已知边界、无担保范围和不可排除的法定责任。
- [GPL-3.0 完整文本](LICENSE)、[版权与修改说明](NOTICE.md)、[第三方资源清单](docs/RESOURCE-LICENSES.md)。
- [当前进度](docs/PROGRESS.md)：本轮增量、未完成项与下一验收范围。

本仓库不附用户书籍、测试备份、私人截图、签名私钥或授权未确认的参考素材包。维护者：[hbxs0571](https://github.com/hbxs0571)。普通问题可通过 [Issues](https://github.com/hbxs0571/legado-with-md3-harmonyos/issues) 反馈；请先删除个人数据。安全问题见 [SECURITY.md](SECURITY.md)。
