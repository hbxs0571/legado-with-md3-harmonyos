# Legado with MD3 for HarmonyOS

基于 [Legado with MD3](https://github.com/HapeLee/legado-with-MD3) 与 [阅读 (Legado)](https://github.com/gedoor/legado) 的 HarmonyOS 原生移植，使用 ArkTS、ArkUI 与 Stage 模型开发。本项目处于开发预览阶段；与上游项目及华为、Google 均无隶属关系，也未获其官方认证或背书。

## 📦 获取与安装

最新构建为 [0.1.0 开发预览](https://github.com/hbxs0571/legado-with-md3-harmonyos/releases/tag/v0.1.0)（Pre-release），提供**未签名 HAP**，未上架应用市场，也不提供签名后的正式发行包。

未签名 HAP 不能双击安装——Windows 没有 HAP 关联程序，这不是包本身的问题。三种装法：

1. **小白安装助手**（推荐）：把 HAP 拖进 [likuai2010/auto-installer](https://github.com/likuai2010/auto-installer)，它读取设备 UDID 自动生成 Profile 并完成签名安装，不需要证书，也不需要 DevEco Studio。该工具为第三方项目，请自行确认来源与许可。
2. **DevEco Studio 自动签名**：打开工程，`File → Project Structure → Signing Configs` 勾选自动签名并登录华为账号，然后运行到设备。
3. **模拟器命令行**：模拟器可覆盖安装未签名包，不需要任何签名配置。

   ```bash
   hdc install -r legado-harmonyos-0.1.0-unsigned.hap
   ```

真机需按设备生成签名，且只能装进已加入 Profile 的设备。自行构建见[构建说明](docs/BUILDING.md)，发行范围见[开源与发行范围](docs/RELEASE.md)。

## 📊 完成度

按上游 README 列出的两组特性逐项对照。**已接**＝可用且有设备验证；**部分**＝主链可用但覆盖不全；**未接**＝上游有、本地没有；**不适用**＝平台无对应能力。

### 分支特性

| 上游条目 | 状态 | 说明 |
| --- | --- | --- |
| 全新 Material Design 3 界面 | 部分 | 主题体系已接，但 M3 色位只落 9 个，容器色与错误色一律降级 |
| 预测性返回手势 | 不适用 | ArkUI 无对应系统能力，设置项只落盘不驱动渲染 |
| 共享元素动画 | 未接 | 上游书封到播放器、封面到详情的 morph 链路本地未做 |
| 个性化阅读界面与菜单配置 | 已接 | 菜单取色链、点击区域、翻页键、进度条行为等近百项 |
| 阅读记录时间轴与章节维度 | 部分 | 时间轴、汇总、最后阅读三视图已接；章节维度统计未做 |
| 漫画阅读 | 部分 | 图片书按一图一页渲染，另有图片样式档；无上游的漫画专用界面 |
| 有声书 | 未接 | 只保留 `bookType` 标记与筛选，无音频书播放器 |
| 发现页 | 已接 | 按书源与分类翻页，`exploreUrl` 四种写法均解析 |
| 书架布局与平板优化 | 已接 | 三种分组样式、网格与列表两套布局、横竖屏独立配置；平板按短边 ≥ 600vp 近似判定 |
| 书籍备注 | 已接 | 编辑页可读写 |
| 智能伴生分组 | 未接 | 上游 13 个内置状态分组里本地只补了「本地未分组」；读状态判据已在书籍详情页，未做成书架页签 |
| 手柄翻页 | 部分 | 音量键与媒体键可翻页；手柄键位 ArkUI 无接管入口 |

### 核心功能

| 上游条目 | 状态 | 说明 |
| --- | --- | --- |
| 多格式阅读 | 已接 | TXT、EPUB、PDF、MOBI/AZW3、UMD 与压缩包（ZIP/CBZ）六类 |
| 智能扫描本地文件 | 未接 | 导入走系统文件选择器，未做目录扫描 |
| 高度自定义 | 已接 | 字体、背景、行距、段距、加粗、简繁转换、文字效果与护眼模式 |
| 净化替换 | 已接 | 规则在正文进入排版前生效，正则跑在 taskpool，单条超时自动停用 |
| 翻页模式 | 已接 | 覆盖、滑动、仿真、滚动、淡入淡出、无动画六档 |
| 完全开源、无广告 | 已接 | GPL-3.0，无广告、分析统计与自有服务端 |

逐行盘点的七张对照表（1226 条）见 [ZIP 兼容总账](docs/parity/STATUS.md)，其中不少「未接」经判断后登记为「不接」（上游有、本项目不做，或平台无对应能力），理由写在表内备注与[已知问题](docs/KNOWN-ISSUES.md)。设备验证范围见[验证记录](docs/VALIDATION.md)，其余文档入口见[文档索引](docs/INDEX.md)。

## ⚠️ 注意事项

- 当前为开发预览，不是稳定发行版；仓库未配置正式签名，也没有应用市场上架版本。[0.1.0 开发预览](https://github.com/hbxs0571/legado-with-md3-harmonyos/releases/tag/v0.1.0) 登记的五条已知问题里，KI-REL1–4 已修复，KI-REL5（浅色模式配色）仍未修。
- 兼容/目标版本配置为 `6.0.0(20)`，尚未做过 API 20 真机验收（只有模拟器 API 26 的验收记录）。
- 应用界面字体（含本地字体文件导入）已在模拟器验收；**阅读器正文的自定义字体导入虽已实现，但还没有设备验证记录**。
- 书籍正文保存在设备本地，备份 ZIP 不包含正文；请另行保管原始书籍文件。
- 备份可能含账号、Cookie、请求头或令牌等敏感信息。公开提交前请检查并清除个人数据。
- 用户导入或配置的内容由用户自行判断来源、许可和使用方式，并遵守适用法律与服务条款。

## 💬 交流

请通过 [GitHub Issues](https://github.com/hbxs0571/legado-with-md3-harmonyos/issues) 反馈项目问题。提交前请移除书名、账号、Cookie、令牌及其他个人信息；安全问题请参阅 [SECURITY.md](SECURITY.md)。

## ❤️ 致谢

- [HapeLee/legado-with-MD3](https://github.com/HapeLee/legado-with-MD3)：上游界面与功能参考。
- [gedoor/legado](https://github.com/gedoor/legado)：原始开源项目及阅读功能基础。
- [wip3l/harmony-book-source-engine](https://github.com/wip3l/harmony-book-source-engine)：在线书源的规则解析与脚本执行引擎（GPL-3.0）。
- [wip3l/qingye-reader](https://github.com/wip3l/qingye-reader)：正文排版引擎的段落构建与逐行切页算法参考（GPL-3.0，按本地接口重写，未整文件复制）。
- 第三方图标和资源来源见[资源许可清单](docs/RESOURCE-LICENSES.md)。

## ⚠️ 用户协议与免责声明

本项目为非官方社区移植工程。使用前请阅读[使用协议](TERMS.md)、[隐私政策](PRIVACY.md)和[免责声明](DISCLAIMER.md)。用户导入或配置的内容由用户自行负责其来源、合法性与使用方式。

项目代码按 [GPL-3.0](LICENSE) 发布；版权归属及修改说明见 [NOTICE.md](NOTICE.md)。第三方依赖和资源可能适用各自的许可。
