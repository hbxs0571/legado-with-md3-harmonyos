# 构建说明

本仓库根目录为 Stage 工程。使用 DevEco Studio 打开根目录，在已安装的 HarmonyOS SDK 环境中同步并构建 entry 模块。

根目录 `.npmrc` 配置 Huawei npm 镜像及 HarmonyOS `@ohos` 仓库。Hvigor 插件依赖固定在 `hvigor/hvigor-config.json5`；DevEco 同步或运行 `hvigorw` 时会自动解析和下载，无需在 IDE 的 Marketplace 单独安装插件。若网络环境要求代理，请在 DevEco/npm 中配置可访问上述仓库的代理。

已记录的开发工具版本为 DevEco Studio 26.0.0.851 / SDK 26，Hvigor 插件由 hvigor/hvigor-config.json5 固定为 6.26.8。应用 compatibleSdkVersion 和 targetSdkVersion 均为 5.0.0(12)；未固定 compileSdkVersion，使用实际开发工具 SDK。因此不能保证不同 SDK 构建逐字节一致，也不能由构建成功推断 API 12 实机兼容。

Windows PowerShell 示例（将工具安装路径替换为本机实际位置）：

$devecoRoot = $env:DEVECO_STUDIO_HOME
if (-not $devecoRoot) { throw '请先设置 DEVECO_STUDIO_HOME' }
$env:DEVECO_SDK_HOME = Join-Path $devecoRoot 'sdk'
$env:JAVA_HOME = Join-Path $devecoRoot 'jbr'
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
& (Join-Path $devecoRoot 'tools\hvigor\bin\hvigorw.bat') --no-daemon --mode module -p product=default -p module=entry@default assembleHap
```

产物通常位于 entry/build/default/outputs/default/entry-default-unsigned.hap。当前没有 signingConfigs，未签名包不是面向普通用户直接安装的正式发行物。自行安装须按自己的设备和开发者配置完成匹配签名；不要把私钥、密码或 Profile 提交到 Git。

本仓库不依赖父目录 Android 工程；上游只作为来源参照。entry 不声明直接运行时 NPM 依赖；根清单为 `ohosTest` 提供 Hypium 开发依赖并带有锁文件。HarmonyOS SDK 与 Hvigor 构建插件仍是必需依赖。干净构建的实际结果见 `VALIDATION.md`。
