# Legado with MD3 for HarmonyOS

Legado with MD3 for HarmonyOS 是基于 [Legado with MD3](https://github.com/HapeLee/legado-with-MD3) 与 [Legado（阅读）](https://github.com/gedoor/legado) 的 HarmonyOS 原生移植工程，使用 ArkTS、ArkUI 与 Stage 模型开发。本项目处于开发预览阶段，持续迁移本地阅读、阅读设置与书架功能；它与上游项目及华为、Google 均无隶属关系，也未获其官方认证或背书。

## 📦 获取与安装

最新构建是 [0.1.0 开发预览](https://github.com/hbxs0571/legado-with-md3-harmonyos/releases/tag/v0.1.0)（Pre-release），附件 `legado-harmonyos-0.1.0-unsigned.hap`。本仓库发布的是**未签名 HAP**，未上架应用市场，也不提供签名后的正式发行包。

未签名 HAP **不能用文件管理器双击安装**——Windows 没有 HAP 关联程序，这不是包本身的问题。安装方式有三种：

**推荐：小白安装助手**（[likuai2010/auto-installer](https://github.com/likuai2010/auto-installer)）。把 `legado-harmonyos-0.1.0-unsigned.hap` 拖进去，它读取已连接设备的 UDID 自动生成 Profile 并完成签名安装，不需要配证书、不需要 DevEco Studio。这是目前最省事的试用方式。

**备选：DevEco Studio 自动签名**。用 DevEco Studio 打开工程，`File → Project Structure → Signing Configs` 勾选「Automatically generate signature」并登录华为账号，然后运行到设备。

**备选：命令行直接装进模拟器**。模拟器可以覆盖安装未签名包，不需要任何签名配置：

```bash
hdc install -r legado-harmonyos-0.1.0-unsigned.hap
```

真机则需要先按设备生成签名（走上面两条路）；无论签名与否，包都只能装进已加入 Profile 的设备。自行构建的命令与产物路径见[构建说明](docs/BUILDING.md)，发行范围与签名要求见[开源与发行范围](docs/RELEASE.md)。

小白安装助手是第三方工具，本项目未参与其开发，请自行确认来源与许可后再使用。

## ✨ 已实现

- **本地阅读**：TXT 与 EPUB，目录、阅读进度、书签、阅读记录，正文处理与文本选择。PDF、MOBI/AZW3、UMD 与压缩包已列入[阅读器对照表](docs/parity/TXT-READER.md)的路线，代码尚未接入。
- **阅读设置**：字体（系统字体，以及本地 TTF/OTF 字体文件与整个字体文件夹的导入）、间距、对齐、文字效果，以及护眼模式（开关、强度、深色自动开启、定时与跨零点）。各项的验证范围以文档为准。
- **书架**：分组方式三档（页签 / 隐藏页签 / 文件夹），网格与列表两套布局，**横屏与竖屏各自独立的布局模式与列数**，封面宽度、卡片底色、分组样式与排序；多选批量操作（设或取消私密、删除、导出书单）、私密分组与单本加锁、拖拽重排、未读角标与标签取色，以及独立的书架管理页与阅读记录概览页。
- **外观与主题**：**14 套调色板**（日间/夜间各一套语义配色）、纯黑深色模式、全 App 背景图片与虚化度、容器圆角/边框/分隔线共 16 项、应用界面字体、自定义主题配色，以及**主题包的导入与导出**。
- **数据兼容**：按 **28 个 Android ZIP 数据类别**逐类盘点——已接入 19 类双向映射，部分接入 5 类（只映射了其中一部分字段），未接入 2 类，不适用 2 类，无仅归档类别。它不等同于完整 Android 数据库迁移，逐类的读写状态与差异见[备份恢复说明](docs/BACKUP-RESTORE.md)。

在线书源抓取与 RSS 拉取已列入[项目队列](docs/PROJECT.md)的范围，但尚未排期，因此还未接入；朗读服务（TTS）已排期（功能队列第 3 项），本地目前零音频能力。WebDAV 备份已接入（上传、下载、远端列表与凭据设置），但只服务备份包，不连书源、不做云同步；账号密码目前明文存 preferences，属已知限制。AI 在线服务、云同步与额外设备形态适配仍在范围之外。界面或备份中出现相关入口或数据类别，不代表对应服务可用。

## 📊 完成度

按上游界面逐块盘点的七张对照表合计 **1226 行**：已接 **968**、未接 **227**、不适用 **31**。「未接」不等于都该做——其中不少经判断后登记为「不接」（上游有、本项目不做，或平台无对应能力），逐行理由写在表内备注与[已知问题](docs/KNOWN-ISSUES.md)里。

| 对照表 | 行数 | 已接 | 未接 | 不适用 |
| --- | --- | --- | --- | --- |
| [书架](docs/parity/BOOKSHELF.md) | 345 | 276 | 64 | 5 |
| [TXT 阅读](docs/parity/TXT-READER.md) | 296 | 218 | 66 | 12 |
| [阅读配置](docs/parity/READER-CONFIG.md) | 189 | 176 | 11 | 2 |
| [书架布局](docs/parity/ZIP-BOOKSHELF-LAYOUT.md) | 122 | 76 | 43 | 3 |
| [书签](docs/parity/ZIP-BOOKMARK.md) | 117 | 83 | 30 | 4 |
| [深色模式](docs/parity/ZIP-THEME.md) | 91 | 81 | 7 | 3 |
| [封面设置](docs/parity/ZIP-COVER.md) | 66 | 58 | 6 | 2 |

「哪一块还没盘」的总览见 [ZIP 兼容总账](docs/parity/STATUS.md)；设备验证范围与遗留问题见[当前进度](docs/PROGRESS.md)、[验证记录](docs/VALIDATION.md)和[已知问题](docs/KNOWN-ISSUES.md)。产品交付口径、架构说明、对照规则、模拟器用法等其余文档的入口见[文档索引](docs/INDEX.md)。

## ⚠️ 注意事项

- 当前为开发预览，不是稳定发行版；仓库未配置正式签名，也没有应用市场上架版本。[0.1.0 开发预览](https://github.com/hbxs0571/legado-with-md3-harmonyos/releases/tag/v0.1.0) 登记的五条已知问题里，KI-REL1–4 已在 r325–r328 修复，KI-REL5（浅色模式配色）仍未修。
- 兼容/目标版本配置为 `5.0.0(12)`，尚无 API 12 真机验收结论。
- 字体方面：应用界面字体（含本地字体文件导入）已在模拟器上验收；**阅读器正文的自定义字体导入虽已实现，但还没有设备验证记录**。
- 书籍正文保存在设备本地，备份 ZIP 不包含正文；请另行保管原始书籍文件。
- 备份可能含账号、Cookie、请求头或令牌等敏感信息。公开提交前请检查并清除个人数据。
- 用户导入或配置的内容由用户自行判断来源、许可和使用方式，并遵守适用法律与服务条款。

## 💬 交流

请通过 [GitHub Issues](https://github.com/hbxs0571/legado-with-md3-harmonyos/issues) 反馈项目问题。提交前请移除书名、账号、Cookie、令牌及其他个人信息；安全问题请参阅 [SECURITY.md](SECURITY.md)。

## ❤️ 致谢

- [HapeLee/legado-with-MD3](https://github.com/HapeLee/legado-with-MD3)：上游界面与功能参考。
- [gedoor/legado](https://github.com/gedoor/legado)：原始开源项目及阅读功能基础。
- [wip3l/qingye-reader](https://github.com/wip3l/qingye-reader)：正文排版引擎的段落构建与逐行切页算法参考（GPL-3.0，按本地接口重写，未整文件复制）。
- 第三方图标和资源来源见[资源许可清单](docs/RESOURCE-LICENSES.md)。

## ⚠️ 用户协议与免责声明

本项目为非官方社区移植工程。使用前请阅读[使用协议](TERMS.md)、[隐私政策](PRIVACY.md)和[免责声明](DISCLAIMER.md)。用户导入或配置的内容由用户自行负责其来源、合法性与使用方式。

项目代码按 [GPL-3.0](LICENSE) 发布；版权归属及修改说明见 [NOTICE.md](NOTICE.md)。第三方依赖和资源可能适用各自的许可。
