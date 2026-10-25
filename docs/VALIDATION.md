# 验证记录

日期：2026-10-25。记录与公开导出对应的工程快照。

## 既有运行记录（历史，不表示本次重跑）

- DevEco Studio 26.0.0.851 / SDK 26；历史 `assembleHap` 构建成功。
- 历史设备为 OpenHarmony 7.0.0.105 / API 26 模拟器，曾安装并运行。另有 Mate90 安装记录。
- 配置的 compatible/target SDK 是 HarmonyOS `5.0.0(12)`。API 26 模拟器运行不能证明 API 12 真机兼容。
- 旧的全量工程内含未签名 HAP 构建产物，本仓库导出已排除所有构建输出。本次未将这些历史产物作为发布包。
- 以上设备记录来自原工程的历史工作；不代表 API 12 真机兼容，也不代表新功能全部回归。

## 当前快照状态

- bundleName：`io.legado.harmony`；versionName：`0.1.0`；versionCode：`1000000`。
- `signingConfigs` 未配置；仓库不含签名材料。
- 模块配置未声明 INTERNET 权限；源码没有应用网络客户端/请求代码的初步检索记录。若新版本加入在线服务，须重新审核权限与隐私说明。
- P1 阅读器整页 UI 与逐项视觉验收未完成；10 月 25 日增量实现有模拟器记录，但仍需完成整体验收。
- 资源当前 118 SVG / 4 PNG，旧资源清单已废弃。路径比对报告为 48 个 SVG 与 Android drawable 精确一致，27 个 SVG 来源待核；详见 RESOURCE-LICENSES.md。

## 本次构建验证

- 通过 `.npmrc` 配置 `https://repo.huaweicloud.com/repository/npm/` 与 `https://repo.harmonyos.com/npm/`；查询确认 `@ohos/hvigor-ohos-plugin@6.26.8` 可解析。
- 在同步当前源文件的独立公开副本中清除 Entry 旧构建目录，再运行 `hvigorw.bat --no-daemon --mode module -p product=default -p module=entry@default assembleHap`，`BUILD SUCCESSFUL`，33 项任务中 32 项执行、1 项为最新。Hvigor 自动安装 `@ohos/hvigor-ohos-plugin@6.26.8`。
- 编译有既有 ArkTS 警告，包括 FileIO 异常处理提示、弃用 API 和 API 12 粘贴板读取授权提示；本次没有编译错误。剪贴板读取由用户主动粘贴并确认系统授权触发。
- Hvigor 提示 `No signingConfig found for product default`。构建成功只证明生成开发用未签名 HAP，不提供发行签名包，也不是 API 12 真机验收。
- 最初失败是因为 npm 指向 `registry.npmmirror.com` 且构建进程启用了离线模式。切换官方源并在线运行后，依赖解析与干净构建均成功。用户级 `.npmrc` 已更新为官方源；若启动 DevEco Studio 的 shell 设置了 `NPM_CONFIG_OFFLINE=true`，需解除该变量或从未设置离线模式的桌面会话启动 DevEco。

**本仓库提供开发预览源码，不代表稳定版、签名发行包或已完成 API 12 兼容验收。**
