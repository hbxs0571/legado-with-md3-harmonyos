# 已知问题与验收边界

更新：2026-10-28。以下条目只记录 E 端当前源码与验证状态能支持的事实，不包含另一台设备的原始记录、用户书目、测试数据、设备标识或本机路径。

## 尚未解决或尚未完成验证

1. **规则超时字段尚未限制运行时执行。** timeoutMillisecond 会在规则数据中保存和传递，但正文/标题替换仍使用同步 RegExp.replace；没有执行时限或中断机制。复杂表达式可能占用界面线程，字段值不能理解为已生效的安全超时。
2. **并发规则写入未串行化。** 仓储按缓存快照写回整组规则；若多个异步保存重叠，存在后写覆盖先写的风险。目前未完成快速并发写入的压力验证。
3. **E 端仅验证到规则管理空状态。** E 端 HAP 构建、安装后，已用 OCR/HDC 导航到“我的→替换净化”空列表；尚未在 E 端创建规则、运行内容替换、文件导入/导出或完成规则的 ZIP 备份恢复全往返。
4. **恢复结果提示仍需二次 UI 核验。** 当前源码已加入新增、更新、跳过计数提示；提示文案的标点与完整显示状态尚未在 E 端设备再次确认。
5. **API 12 真机兼容未验证。** 当前构建和有限设备检查不能替代 API 12 真机验收。
6. **在线 URL 导入未接入。** 规则可通过本地文件或用户粘贴文本导入；应用没有通过 URL 获取规则的网络能力。
7. **TXT 目录规则的文件导入与 ZIP 往返只在模拟器验过。** 导入/导出已接通（`TxtTocRuleRepository.pickImportFile` / `saveExportFile` + `TxtTocRuleImporter`），但只在 OpenHarmony API 26 模拟器上实测通过，API 12 真机未验证。
9. **已导入的 TXT 不会因规则变更而重新识别目录。** 导入时选中的章节正则会固定在 `Book.tocRule` 上，这是有意设计（规则调整不应打乱已有书的目录）；但书架的「更新目录」目前是占位，用户没有主动重算目录的入口。

## 已修复

- **TXT 目录规则页补齐选择模式与条目菜单**（2026-10-28）。对照上游 `TxtRuleScreen.kt` 补了四项：选择栏加「反选」（在当前筛选结果内取差集）、「启用」「停用」「导出」；条目右侧加「更多」菜单（置顶/置底/删除）；批量删除与单条删除统一走确认面板（与 `RuleListScaffold.kt:75-86` 的 `AppAlertDialog` 语义一致）。实现位置 `entry/src/main/ets/pages/ProfileSubPages.ets` 的 `TxtTocRulesPage`，置顶/置底落在 `entry/src/main/ets/data/TxtTocRuleRepository.ets` 的 `moveToEdge()`。设备实测：反选 0→27→0、批量停用 27 条全变 `enable:false`、批量启用恢复、取消删除后规则数不变、置底后「目录(去空白)」从第 0 位移到第 26 位、置顶后回第 0 位、单条删除 27→26、批量导出 26 条且 `serialNumber` 连续。
- **CRLF 文本上所有内置 TXT 目录规则 0 命中**（2026-10-28 修复）。ArkTS 的正则在多行模式下只把 `\n` 当作行终止符，`$` 不会匹配到 `\r` 之前；Windows 文本每行以 `\r\n` 结尾，因此所有以 `.{0,30}$` 收尾的内置规则在 CRLF 文本上都不命中，书被误判成「没有可用目录规则」而退回按字数分章，读起来只有一章。修复位置 `entry/src/main/ets/data/TxtTocRuleRepository.ets` 的 `selectForSample()`：匹配前先把样本行尾归一为 `\n`。章节切分不受影响，`splitChapterStarts()` 逐行处理时本来就已去掉行尾 `\r`。
- **TXT 目录规则接入备份/恢复**（2026-10-28 补齐）。备份类别未被排除时生成根级 `txtTocRule.json`；恢复时逐条解析并导入，同 ID 或同章节正则更新本地规则并保留本地 ID 和顺序，非法正则计入跳过。实现位置 `entry/src/main/ets/data/BackupRepository.ets` 的 `createBackup()` 与 `restore()`，提示文案由 `entry/src/main/ets/pages/Index.ets` 的 `describeTxtTocRuleRestore()` 生成。设备实测：备份 ZIP 解包含 `txtTocRule.json`（9190 B / 25 条）；用含 2 条有效规则 + 1 条非法正则的 ZIP 恢复后规则从 25 条变 27 条，提示「TXT 目录规则新增 2 条、跳过 1 条无效规则」。
- **规则文件导出写出 0 字节空文件**（2026-10-28 修复）。`saveExportFile()` 原来先用 `util.TextEncoder.encodeInto(content)` 转成 `Uint8Array` 再 `fileIo.writeSync(fd, bytes)`，在模拟器上抛 `{ code: 13900020 }`（EINVAL），文件被创建出来但内容为空，界面提示「导出目录规则失败」。修复方式是把字符串直接传给 `writeSync`，由底层按 UTF-8 编码。`TxtTocRuleRepository.ets` 与 `ReplaceRuleRepository.ets` 两处同源实现都已改，实测导出 `txtTocRule-*.json`（9190 B / 25 条）与 `replaceRules-*.json`（607 B / 2 条）内容正确。

## 已纳入源码、但不等同于完整验收的行为

- 导入批次内重复 ID 会分配唯一 ID；导入到本地时，同 ID 或同 pattern 视为匹配项，覆盖字段时保留本地 ID 和顺序。
- 备份包含替换净化规则类别且该类别未被排除时，会生成 replaceRule.json；即使当前没有规则，也写出空数组，避免从旧归档夹带已删除规则。TXT 目录规则采用同样的处理方式，生成 txtTocRule.json。
- 规则管理列表与阅读处理面板共用稳定行键；阅读处理面板的开关作用于当前书的规则设置。
- 对应 ArkTS 源码已通过当前公开副本构建。规则创建、文件流转和 ZIP 往返仍按上面的验证边界记录。
