# Legado with MD3 for HarmonyOS

使用 ArkTS / ArkUI / Stage 开发的 HarmonyOS 原生阅读器，社区独立移植自 [Legado with MD3](https://github.com/HapeLee/legado-with-MD3)，上游阅读项目为 [Legado](https://github.com/gedoor/legado)。本项目不代表上游、华为或 Google 官方，不表示获得其背书。

**当前是开发预览源码，尚未完成全部迁移与验收，不是成熟稳定版。当前不提供经过发行签名和安装验证的安装包。**

## 当前进度（2026-10-24 源码快照）

| 范围 | 已有能力 | 尚未完成 / 限制 |
| --- | --- | --- |
| P1 原生 UI | 首页、书架、发现、订阅、我的及多个设置/直接目的页；深色界面优先 | 整体未验收完成；当前主线为阅读器设置整页 UI、弹层与同书同态对照，部分控件仅为预览或显示未迁移 |
| P2 本地阅读 | TXT/EPUB 选择导入、本地书架、目录/正文、分页与进度恢复、部分阅读设置、搜索与单书管理 | 有历史验证，最新快照未重新完成全部设备回归；EPUB CSS/复杂排版不完整，图片混排及缺资源情况未完整验收 |
| P3 开源发行 | 此仓库整理当前源码、构建配置、许可、隐私与使用说明 | 公开源码不代表 P1/P2/P4 已收口；正式签名安装包与应用市场上架未交付 |
| P4 备份恢复 | Android ZIP 导入预览、受支持书目/进度/设置恢复、分类过滤和再导出、缺正文书目提示 | 部分 JSON/XML 只原样归档，不激活对应业务；无全类别事务回滚、完整 Android 数据库语义或跨设备加密凭据兼容保证 |
| 在线业务 | 界面或备份归档中可能出现对应入口与数据 | 在线书源执行、在线搜索、RSS 拉取、TTS、AI、WebDAV、云同步和 Web 服务尚未接入 |

备份 ZIP 不包含书籍正文；请另行保管原始 TXT/EPUB。备份可能带有原 Android 数据中的账号信息、Cookie、请求头或令牌，**不要把个人备份上传到 Issues 或公开仓库**。

当前资源清单核对了 109 个 SVG，其中 48 个与 Android drawable 路径精确一致；另有 17 个新增 SVG 尚未找到可独立核实的上游路径来源。来源/许可状态逐项标在 [资源清单](docs/RESOURCE-LICENSES.md)，不能把该项审计说成已完成。

## 获取与构建

本仓库根目录就是 HarmonyOS 工程，不需要父目录 Android 工程即可构建。请阅读 [构建说明](docs/BUILDING.md) 和 [验证记录](docs/VALIDATION.md)。

- 配置兼容/目标版本：`5.0.0(12)`；这不是 API 12 真机兼容性证明。
- 历史开发环境：DevEco Studio 26.0.0.851 / SDK 26；历史设备记录为 OpenHarmony 7 / API 26 模拟器。
- 应用内部版本：`0.1.0`，versionCode `1000000`，bundleName `io.legado.harmony`。内部名称与版本沿用开发工程，尚未作为稳定升级契约。

## 隐私、使用与许可

- [隐私政策](PRIVACY.md)：实际处理的数据、备份风险、存储与删除方式。
- [使用协议](TERMS.md)：开发预览的使用说明，开源许可优先，不额外限制 GPL 权利。
- [免责声明](DISCLAIMER.md)：已知边界、无担保范围和不可排除的法定责任。
- [GPL-3.0 完整文本](LICENSE)、[版权与修改说明](NOTICE.md)、[第三方资源清单](docs/RESOURCE-LICENSES.md)。

本仓库不附用户书籍、测试备份、私人截图、签名私钥或授权未确认的参考素材包。维护者：[hbxs0571](https://github.com/hbxs0571)。普通问题可通过 [Issues](https://github.com/hbxs0571/legado-with-md3-harmonyos/issues) 反馈；请先删除个人数据。安全问题见 [SECURITY.md](SECURITY.md)。
