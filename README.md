# Legado with MD3 for HarmonyOS

简体中文

## 📖 介绍

Legado with MD3 for HarmonyOS 是基于 [Legado with MD3](https://github.com/HapeLee/legado-with-MD3) 与 [Legado（阅读）](https://github.com/gedoor/legado) 的 HarmonyOS 原生移植工程，使用 ArkTS、ArkUI 和 Stage 模型开发。

本项目处于开发预览阶段，持续迁移本地阅读与书架功能。它与上游项目及华为、Google 均无隶属关系，也未获其官方认证或背书。

## ✨ 分支特性

- HarmonyOS 原生界面与书架，支持本地 TXT、EPUB、书架分组、列表/网格布局与排序设置。
- 阅读器包含目录、阅读进度、书签、阅读设置、正文处理和文本选择等已接入能力；完整阅读体验仍在迁移。
- 阅读记录、TXT 目录规则、标注与书签等模块已完成部分设备检查。具体验证范围和遗留问题见[当前进度](docs/PROGRESS.md)、[验证记录](docs/VALIDATION.md)及[已知问题](docs/KNOWN-ISSUES.md)。
- 对部分 Android ZIP 书目、设置和规则数据提供兼容预览与字段映射，不代表完整 Android 数据库迁移。

## 🛠️ 核心功能

1. **本地阅读：** 支持本地 TXT、EPUB、目录和阅读进度管理。
2. **书架管理：** 支持分组及部分布局、排序设置；设置项的设备验证范围以文档记录为准。
3. **阅读辅助：** 包含书签、阅读记录、TXT 目录规则和正文处理等逐步迁移的模块。
4. **HarmonyOS 工程：** 使用 ArkTS、ArkUI 与 Stage 模型，可按[构建说明](docs/BUILDING.md)在 DevEco Studio 中构建。
5. **开源：** 项目采用 GPL-3.0，第三方资源来源和许可另见[资源清单](docs/RESOURCE-LICENSES.md)。

在线书源抓取、在线搜索、RSS、TTS、AI、WebDAV、云同步和 Web 服务尚未接入。界面或备份中出现相关入口或数据类别，不代表对应服务可用。

## ⚠️ 注意事项

- 当前为开发预览，不是稳定发行版；仓库未配置正式签名，不提供正式发行安装包。
- 已配置兼容/目标版本 `5.0.0(12)`，但尚无 API 12 真机兼容验收结论。
- 书籍正文保存在设备本地，备份 ZIP 不包含正文；请另行保管原始 TXT/EPUB。
- 备份可能含账号、Cookie、请求头或令牌等敏感信息。公开提交前请检查并清除个人数据。
- 用户配置或导入的书源、规则及第三方内容由用户自行判断来源与使用权限，并遵守适用法律和服务条款。

## 💬 交流

请通过 [GitHub Issues](https://github.com/hbxs0571/legado-with-md3-harmonyos/issues) 反馈项目问题。提交前请移除书名、账号、Cookie、令牌及其他个人信息；安全问题请参阅 [SECURITY.md](SECURITY.md)。

## ❤️ 致谢

- [HapeLee/legado-with-MD3](https://github.com/HapeLee/legado-with-MD3)：上游界面与功能参考。
- [gedoor/legado](https://github.com/gedoor/legado)：原始开源项目及阅读功能基础。
- 第三方图标和资源来源见[资源许可清单](docs/RESOURCE-LICENSES.md)。

## ⚠️ 用户协议与免责声明

本项目为非官方社区移植工程。使用前请阅读[使用协议](TERMS.md)、[隐私政策](PRIVACY.md)和[免责声明](DISCLAIMER.md)。用户导入或配置的内容由用户自行负责其来源、合法性与使用方式。

项目代码按 [GPL-3.0](LICENSE) 发布；版权归属及修改说明见 [NOTICE.md](NOTICE.md)。第三方依赖和资源可能适用各自的许可。
