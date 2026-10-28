# Hypium / UI 自动化测试

## 已接入能力

- 根工程通过开发依赖安装 `@ohos/hypium` 1.0.25；`entry` 模块新增 `ohosTest` 测试目标和 TestAbility。
- UI 操作使用 HarmonyOS `@ohos.UiTest`，依据控件文本等语义属性查找、点击和断言，Hypium 用例的断言不依赖截图 OCR。
- 人工导航与点击验证仍按 [验证记录](VALIDATION.md) 的 OCR 规范执行：先识别再点击、点击后重新识别确认到达。两者不冲突——Hypium 走控件语义，人工验收走 OCR 消歧。
- 首个冒烟用例启动 `io.legado.harmony` 的 `EntryAbility`，等待后断言“首页”或首次启动向导“欢迎”至少有一个可见。
- UI 测试 HAP 已用当前 DevEco SDK 成功构建；该构建没有运行测试用例，也没有安装测试 HAP。应用声明的 compatible/target API 仍为 12。

## 运行

在 DevEco Studio 中选择 `entry@ohosTest` 测试目标，运行 `LaunchSmoke.test.ets` 或整个 Hypium 测试套件。测试会启动主应用并停留在首页或首次启动向导，不清除应用数据。

命令行只构建测试 HAP、不运行测试用例：

```powershell
hvigorw --mode module -p product=default -p module=entry@ohosTest assembleHap
```

本机未设置有效的 `DEVECO_SDK_HOME` 时，构建前需在当前 PowerShell 进程临时设置正确的 DevEco SDK 路径；不要为此修改系统环境变量。

## 使用边界

- Hypium 适合稳定地按文本、控件 ID、类型等语义属性验证和操作应用界面；当前只覆盖启动冒烟，不代表阅读业务回归已覆盖。
- 视觉布局是否贴近 Android 参考图仍需截图审查或视觉比较。新增页面测试时优先使用控件 ID 和可访问文本，降低对 OCR 的依赖。
- 项目自动导航规范仍以 `VALIDATION.md` 为准：当前设备上的截图识别与点击流程继续使用 HMNextAuto；Hypium 用于可重复的 UI 用例。
