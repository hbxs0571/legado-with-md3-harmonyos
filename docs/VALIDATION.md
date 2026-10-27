# 验证记录

日期：2026-10-28。记录与公开导出对应的工程快照。

## 2026-10-28 E 端替换规则整合检查

- E 端整合源码构建并覆盖安装到 HOS 后，通过 OCR/HDC 进入“我的→替换净化”空列表状态。
- 本次 E 端检查仅确认入口和空状态可达；没有创建规则，也没有做规则文件导入/导出或 ZIP 规则恢复全往返。
- 本地代码已实现规则 JSON 映射、冲突合并、无效正则跳过和空规则数组备份；这些实现不等同于 E 端全流程已验收。
- E 端未验证恢复结果提示的标点细节；API 12 真机兼容仍未验证。

本次公开副本 clean 构建结果另见下方公开基线构建条目；未签名 HAP 不作为发行文件。

## 2026-10-27 公开基线构建

- 在独立公开副本清理 Entry 旧构建输出后，使用 DevEco 附带的 Hvigor 入口执行 clean 和 assembleHap。
- 构建结果为 BUILD SUCCESSFUL；共 33 项任务，21 项执行，12 项为最新。
- ArkTS 编译有既有异常处理和弃用 API 警告；未出现编译错误。Hvigor 提示没有 signingConfig。
- 生成的 HAP 未签名，仅留在被 Git 忽略的本机构建目录；未作为安装包提交或发布。
- 本次未进行设备安装、API 12 真机或整页 UI 验收。具体模块范围见 MODULE-STATUS.md。

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
- UI 与导航中，阅读器整页及逐项视觉验收未完成；五个阅读相关路由仍为实现中，10 月 26 日增量有模拟器记录但需要继续验收。
- 资源当前 133 SVG / 4 PNG。路径比对报告为 50 个 SVG 与 Android drawable 精确一致；39 个 SVG 有 AndroidX Material / Apache-2.0 来源记录；此前待核的 10 个 SVG 已完成来源映射，其中 2 个箭头是 GPL-3.0 近似 UI 映射，详见 RESOURCE-LICENSES.md。

## 本次构建验证

- 在独立公开副本使用 DevEco Studio 26.0.0.851 附带的 Hvigor 入口执行 Entry clean 后的 `assembleHap`；33 项任务中 32 项执行、1 项为最新，`BUILD SUCCESSFUL`。
- ArkTS 编译存在既有异常处理、弃用 API 与剪贴板授权提示；本次没有编译错误。Hvigor 提示 `No signingConfig found for product default`。
- 生成的 HAP 未签名，仅留在 Git 忽略的本机构建目录；未作为安装包提交或发布。构建成功只证明源码可构建，不代表 API 12 真机兼容或完成整页功能验收。

**本仓库提供开发预览源码，不代表稳定版、签名发行包或已完成 API 12 兼容验收。**
