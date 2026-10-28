# Legado with MD3 for HarmonyOS

## 📖 介绍

Legado with MD3 for HarmonyOS 是一个面向 HarmonyOS 的原生阅读器移植工程，界面和功能参考 [Legado with MD3](https://github.com/HapeLee/legado-with-MD3)，阅读能力和兼容格式参考 [Legado](https://github.com/gedoor/legado)。项目使用 ArkTS、ArkUI 与 Stage 模型开发。

本仓库由社区维护，与上游项目及华为、Google 无隶属关系，也不表示获得其官方认证或背书。代码依照 GPL-3.0 开源，版权和修改信息见 [NOTICE.md](NOTICE.md)。

> **当前为开发预览。** 功能迁移和设备验收仍在进行中；仓库不提供正式签名、面向普通用户发行的安装包。

## ✨ 当前实现

- **HarmonyOS 界面：** 已有首页、书架、发现、订阅、我的及部分设置页面。阅读器和多个阅读相关路由仍在完善，部分操作会明确提示尚未迁移。
- **本地阅读：** 已接入 TXT、EPUB、本地书架、目录、阅读进度、书签、阅读设置和正文处理。复杂 EPUB 排版与章节内嵌图片支持仍有限。
- **TXT 目录规则：** 支持内置规则导入、JSON 导入导出、按规则导入 TXT、卷头识别与折叠。E 端已核验内置 27 条规则重启保留、JSON 导出再导入、TXT 分卷显示和阅读进度持久化；完整 CRUD/批量操作仍需补测。
- **替换净化：** 源码包含规则管理、导入导出、按书启停、阅读时应用及 Android ZIP 规则映射。更细的设备验收范围见[当前进度](docs/PROGRESS.md)与[已知问题](docs/KNOWN-ISSUES.md)。
- **Android ZIP：** 对部分书目、进度、设置和规则提供预览与字段映射；未映射的类别按兼容数据安全保留或忽略，不等同于完整 Android 数据库迁移。
- **尚未接入：** 在线书源抓取、在线搜索、RSS、TTS、AI、WebDAV、云同步和 Web 服务。界面或备份中出现相关项目，不代表对应在线功能可用。

各模块的最新范围、未完成项和验证边界见[当前进度](docs/PROGRESS.md)、[模块状态](docs/MODULE-STATUS.md)和[已知问题](docs/KNOWN-ISSUES.md)。功能实施队列见[项目队列](docs/PROJECT.md)。

## 🛠️ 获取与构建

本仓库根目录即 HarmonyOS Stage 工程，无需 Android 父工程即可打开。请按[构建说明](docs/BUILDING.md)使用 DevEco Studio 构建，并查看[验证记录](docs/VALIDATION.md)了解已核验的工具和设备范围。

当前兼容/目标版本配置为 `5.0.0(12)`，不代表已在 API 12 真机上验收。项目尚未配置发行签名；本仓库不提供可直接作为正式发行版安装的 HAP。

## ⚠️ 注意事项

- 书籍正文保存在用户设备中，备份 ZIP 不包含书籍正文，请另行保管原始 TXT/EPUB。
- 备份可能包含账号信息、Cookie、请求头或令牌等敏感数据。请勿将个人备份、规则文件或含隐私的截图上传到公开仓库或 Issue。
- 用户导入或配置的书源、规则及第三方内容由用户自行判断来源和使用权限；请遵守适用法律法规及相关服务条款。

## 📄 隐私、协议与开源许可

- [隐私政策](PRIVACY.md)：应用处理的数据、备份风险及本地数据说明。
- [使用协议](TERMS.md)：开发预览使用说明。
- [免责声明](DISCLAIMER.md)：适用范围与责任边界。
- [GPL-3.0 许可全文](LICENSE)、[版权与修改说明](NOTICE.md)。
- [第三方资源来源与许可](docs/RESOURCE-LICENSES.md)。

## 💬 反馈

一般问题请通过 [GitHub Issues](https://github.com/hbxs0571/legado-with-md3-harmonyos/issues) 反馈，并先移除书名、账号、Cookie、令牌及其他个人信息。安全问题请参阅 [SECURITY.md](SECURITY.md)。

## ❤️ 致谢

感谢 [Legado with MD3](https://github.com/HapeLee/legado-with-MD3) 与 [Legado](https://github.com/gedoor/legado) 项目提供的上游代码、功能参考和社区积累。第三方图标及资源的具体来源和许可记录见[资源清单](docs/RESOURCE-LICENSES.md)。
