# 验证记录

日期：2026-10-24。记录与公开导出对应的工程快照。

## 既有运行记录（历史，不表示本次重跑）

- DevEco Studio 26.0.0.851 / SDK 26；历史 `assembleHap` 构建成功。
- 历史设备为 OpenHarmony 7.0.0.105 / API 26 模拟器，曾安装并运行。另有 Mate90 安装记录。
- 配置的 compatible/target SDK 是 HarmonyOS `5.0.0(12)`。API 26 模拟器运行不能证明 API 12 真机兼容。
- 旧的全量工程内含未签名 HAP 构建产物，本仓库导出已排除所有构建输出。本次未将这些历史产物作为发布包。
- 以上是原工程的历史记录，不是对当前公开树完成的重新构建、干净环境验证或全设备回归。

## 当前快照状态

- bundleName：`io.legado.harmony`；versionName：`0.1.0`；versionCode：`1000000`。
- `signingConfigs` 未配置；仓库不含签名材料。
- 模块配置未声明 INTERNET 权限；源码没有应用网络客户端/请求代码的初步检索记录。若新版本加入在线服务，须重新审核权限与隐私说明。
- P1 阅读器整页 UI 与逐项视觉验收未完成；TXT/EPUB 阅读、Android ZIP 恢复有既有记录，但发布快照仍需后续回归。
- 资源当前 109 SVG / 4 PNG，旧资源清单已废弃。路径比对报告为 48 个 SVG 与 Android drawable 精确一致；这不是所有资源的完整授权证明，详见 RESOURCE-LICENSES.md。

## 本次构建尝试

在独立导出目录运行 `hvigorw.bat --no-daemon --mode module -p product=default -p module=entry@default assembleHap`，构建在安装工具依赖阶段停止，尚未进入源码编译：当前 pnpm 镜像 `registry.npmmirror.com` 对 `@ohos/hvigor-ohos-plugin` 返回 HTTP 404。故本次没有当前快照构建通过结论，也没有可供发行的 HAP。上面的历史成功记录不可替代这次验证。

**本仓库提供开发预览源码，不代表稳定版、签名发行包或已完成 API 12 兼容验收。**
