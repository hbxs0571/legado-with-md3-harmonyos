# 版权、来源与修改说明

Legado with MD3 for HarmonyOS 是由 hbxs0571 维护的社区独立原生移植。上游为 HapeLee/legado-with-MD3（r258 移交点 `67970a10b16f90d3cdaf50b487a31bf75950f938`，当前对照基线 `bba5c64`，比移交点新 26 个提交），其上游为 gedoor/legado。原有作品版权归各自作者和贡献者所有；未声称原 Android 项目由本项目创作。

自 2026-10-22 起新增/改写的 ArkTS、ArkUI、Stage 工程、本地阅读及 Android ZIP 兼容实现作为 GPL-3.0 衍生工程提供，完整文本见 LICENSE。此次 2026-10-24 公开快照整理了独立工程结构、公开文档与资源来源；不会附带私人开发历史、用户内容和凭据。各修改文件中的通知及资源清单说明转换方式。

Android drawable 转换资源保留原项目来源。Material 图标来自 AndroidX Compose Material Icons 1.7.8 / Google Material Design Icons，适用 Apache-2.0。Copyright The Android Open Source Project；适用的 Apache-2.0 完整许可文本见 licenses/Apache-2.0.txt；本仓库中的转换图标不保留 AndroidX Kotlin 原始源文件。图标对应表和目前无法独立追溯的资源见 docs/RESOURCE-LICENSES.md。本项目转换为 SVG、调整填色；不宣称这些图标为原创。

文件管理器四个 PNG 来源为上游 FilePickerIcon.java 的字节数组，保留原作者署名：李玉江；原文件标注由 https://github.com/gzu-liyujiang/Image2ByteVar 生成。它们随上游项目的 GPL 来源记录分发；字节一致性在资源审计中核对。

系统 SDK、DevEco、Hvigor 及相关开发工具按各自条款提供，不因本仓库 GPL 而重新许可；本仓库不附其二进制。原参考素材包中的未确认字体、背景和品牌图片不在此仓库中。项目许可不授予第三方商标权。

HarmonyOS 包内置 TXT 目录规则 JSON 共 27 条，与上游 HapeLee/legado-with-MD3 的 `app/src/main/assets/defaultData/txtTocRule.json` 逐字节一致，按 GPL-3.0 随项目分发；来源与哈希见 `docs/RESOURCE-LICENSES.md`。

在线书源引擎整包引入：本仓库的 `third_party/harmony-book-source-engine/` 目录是 wip3l/harmony-book-source-engine 的完整源码副本，遵循 GPL-3.0 分发。

Copyright (c) 2026 李其健
Source code: https://github.com/wip3l/harmony-book-source-engine
License: GNU General Public License v3.0，另附第 7 条附加许可「Harmony Book AI Engine Linking Exception 1.0」
上游来源：extracted from 开源轻页 / qingye-reader, commit 6f96187

该附加许可按 GPL-3.0 第 7 条授予，允许链接 Harmony Book AI Engine 的衍生作品使用更宽松的条款。本项目不链接该引擎，因此不依赖该例外；依据第 7 条末句，本副本在传递时可删除该附加许可。本仓库保留原文件不做改动，仅为完整呈现上游授权状态。

该目录同时包含第三方组件：`quickjs/` 为 @devzeng/quickjs（ohos_quickjs）对 QuickJS 的 HarmonyOS 移植，MIT 许可，Copyright (c) 2026 zengjing；内嵌 QuickJS 引擎由 Fabrice Bellard 与 Charlie Gordon 编写，MIT 许可；OpenHarmony NAPI wrapper 遵循 Apache-2.0，Copyright Huawei；脚本压缩内置的 acorn 遵循 MIT。各组件的完整许可文本见 `third_party/harmony-book-source-engine/THIRD_PARTY_LICENSES.txt`，该文件同时随应用打包，可在应用内「开源许可证」页查看。

本仓库对该目录的改动仅限于 `sourceengine/src/main/ets/core/rule/AnalyzeUrl.ts` 的 `cleanBaseUrl` 方法（修正章节地址的 `#` 片段截断），以及 `build-profile.json5`、`entry/oh-package.json5` 中把它接为本地依赖的配置。其余文件与上游一致。

正文排版引擎的段落构建与逐行切页算法参考 wip3l/qingye-reader 的 `core/reader/ReaderV2Paginator`，按其 GPL-3.0 条款使用。该参考工程同为 GPL-3.0，与本仓库许可兼容；本仓库只借鉴算法思路并按本地接口重写（`entry/src/main/ets/reader/ReaderTextLayoutEngine.ets`），未整文件复制其源码，也未引入其对外页面类型、偏好键或渲染通道。来源与说明见 `docs/RESOURCE-LICENSES.md`。
