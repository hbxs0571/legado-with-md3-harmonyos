# Legado with MD3 for HarmonyOS

简体中文

## 📖 介绍

Legado with MD3 for HarmonyOS 是基于 [Legado with MD3](https://github.com/HapeLee/legado-with-MD3) 与 [Legado（阅读）](https://github.com/gedoor/legado) 的 HarmonyOS 原生移植工程，使用 ArkTS、ArkUI 和 Stage 模型开发。

本项目处于开发预览阶段，持续迁移本地阅读、阅读设置与书架功能。它与上游项目及华为、Google 均无隶属关系，也未获其官方认证或背书。

## ✨ 分支特性

- HarmonyOS 原生界面与书架，支持本地 TXT、EPUB、分组、列表/网格布局和排序设置。
- 阅读器包含目录、阅读进度、书签、阅读记录、正文处理、文本选择和部分排版设置。
- 可选择系统字体；源码也支持导入本地 TTF/OTF 字体文件，真实字体文件导入和 EPUB 字体兼容仍待设备验证。
- Android ZIP 兼容按 **28 个数据类别**逐类盘点，清单见[备份恢复说明](docs/BACKUP-RESTORE.md)：已接入 5 类、部分接入 4 类、未接入 5 类、仅归档 14 类。它不等同于完整 Android 数据库迁移。
- 逐界面的上游对照与「哪一块还没盘」见[ZIP 兼容总账](docs/parity/STATUS.md)与三张对照表（[书架](docs/parity/BOOKSHELF.md)、[书签](docs/parity/ZIP-BOOKMARK.md)、[阅读配置](docs/parity/READER-CONFIG.md)）。
- 设备验证范围和遗留问题见[当前进度](docs/PROGRESS.md)、[验证记录](docs/VALIDATION.md)、[备份恢复说明](docs/BACKUP-RESTORE.md)和[已知问题](docs/KNOWN-ISSUES.md)。

## 🛠️ 核心功能

1. **本地阅读：** 支持 TXT、EPUB、目录与阅读进度管理。
2. **阅读设置：** 接入字体、间距、对齐、文字效果和部分护眼设置；各设置的验证范围以文档为准。
3. **书架管理：** 支持分组及部分布局、筛选和排序设置；私有标记与分组刷新目前不控制实际权限或更新行为。
4. **数据兼容：** 对 Android ZIP 的 28 个数据类别逐类处理：已接入的 5 类双向映射，部分接入的 4 类只映射了其中一部分字段，其余 19 类做预览或安全归档保留、不导入原生功能。各类的读写状态与差异见[备份恢复说明](docs/BACKUP-RESTORE.md)。注意本地有自己的阅读记录三层仓储，但 Android ZIP 里的 `readRecord.json` 属仅归档，不导入这套原生记录。
5. **开源：** 项目采用 GPL-3.0；第三方资源来源和许可见[资源清单](docs/RESOURCE-LICENSES.md)。

在线书源抓取、在线搜索、RSS、TTS、AI、WebDAV、云同步和 Web 服务尚未接入。界面或备份中出现相关入口或数据类别，不代表对应服务可用。

## ⚠️ 注意事项

- 当前为开发预览，不是稳定发行版；仓库未配置正式签名，也不提供正式发行安装包。
- 兼容/目标版本配置为 `5.0.0(12)`，尚无 API 12 真机验收结论。
- 书籍正文保存在设备本地，备份 ZIP 不包含正文；请另行保管原始 TXT/EPUB。
- 备份可能含账号、Cookie、请求头或令牌等敏感信息。公开提交前请检查并清除个人数据。
- 用户导入或配置的内容由用户自行判断来源、许可和使用方式，并遵守适用法律与服务条款。

## 💬 交流

请通过 [GitHub Issues](https://github.com/hbxs0571/legado-with-md3-harmonyos/issues) 反馈项目问题。提交前请移除书名、账号、Cookie、令牌及其他个人信息；安全问题请参阅 [SECURITY.md](SECURITY.md)。

## ❤️ 致谢

- [HapeLee/legado-with-MD3](https://github.com/HapeLee/legado-with-MD3)：上游界面与功能参考。
- [gedoor/legado](https://github.com/gedoor/legado)：原始开源项目及阅读功能基础。
- 第三方图标和资源来源见[资源许可清单](docs/RESOURCE-LICENSES.md)。

## ⚠️ 用户协议与免责声明

本项目为非官方社区移植工程。使用前请阅读[使用协议](TERMS.md)、[隐私政策](PRIVACY.md)和[免责声明](DISCLAIMER.md)。用户导入或配置的内容由用户自行负责其来源、合法性与使用方式。

项目代码按 [GPL-3.0](LICENSE) 发布；版权归属及修改说明见 [NOTICE.md](NOTICE.md)。第三方依赖和资源可能适用各自的许可。
