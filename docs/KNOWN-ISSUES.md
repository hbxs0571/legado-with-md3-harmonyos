# 已知问题与缺陷记录

记录已确认的缺陷、其成因与处理状态，以及尚未解决的遗留风险。本文件只写源码和模拟器实测能确认的事实；推测项单独标注为「待复核」。

更新：2026-10-27。

## 已修复

### 1. 批量操作后列表开关不刷新

**现象**：进入多选模式后批量停用规则，存储已正确写入（重新进入页面时开关全部关闭），但当次操作后列表里的开关仍停在原状态。

**成因**：规则列表 `ForEach` 的 key 只用 `rule.id`。批量操作不改变 id，ArkUI 认为节点未变化便复用旧节点，`Toggle` 保持旧值。

**修复**：把影响行展示的字段并入 key，见 `entry/src/main/ets/pages/ProfileSubPages.ets:240` 的 `ruleRowKey()`：

```ts
private ruleRowKey(rule: ReplaceRule): string {
  return `${rule.id}_${rule.isEnabled ? 1 : 0}_${rule.name}_${rule.group}_${rule.scopeContent ? 1 : 0}${rule.scopeTitle ? 1 : 0}`;
}
```

调用点在 `entry/src/main/ets/pages/ProfileSubPages.ets:538`。

**验证**：全选 4 条规则点停用后重新进入，4 个开关均为关闭；全选点启用后均为开启。

**同类风险**：仓库内其他 `ForEach` 若也用 `id` 作 key 且节点内容随状态变化，可能有一致问题。本次只修了替换规则列表，未做全仓排查。

### 2. 新建替换规则默认对正文不生效

**现象**：新建规则后不手动点「内容」chip 直接保存，规则在列表中显示为「默认 · 」（无「正文」标记），对书籍正文完全不生效；在编辑页菜单打开「测试规则」试跑，提示「当前没有启用中的正文规则，样例文本未被改动」。

**成因**：`ReplaceRuleEditPage` 的 `scopeContent` 初始值是 `false`，而 `ReplaceRuleRepository.previewContent()` 与正文替换逻辑都只处理 `scopeContent === true` 的规则：

- `entry/src/main/ets/data/ReplaceRuleRepository.ets:469` 试跑过滤条件
- `entry/src/main/ets/data/ReplaceRuleRepository.ets:499` 正文替换过滤条件

上游 Android 的 `ReplaceRule.scopeContent` 默认为 `true`（见 `app/src/main/java/io/legado/app/data/entities/ReplaceRule.kt`），本地移植时默认值被写反。

**修复**：`entry/src/main/ets/pages/ProfileSubPages.ets:601` 改为默认 `true`，并加注释说明与上游对齐的原因。

**验证**：新建规则后「内容」chip 默认勾选，列表副标题显示「默认 · 正文」；试跑 `abc` → `XYZ` 对样例 `aabbcc abc` 输出 `aabbcc XYZ`，提示「共 1 条正文规则，其中 1 条改动了样例文本」。

**为何此前未暴露**：P1 阶段测试编辑保存时用的是已有规则，其 `scopeContent` 从存储读回恰好为真，掩盖了新建路径的默认值问题。

## 遗留风险（待决策）

### A. 旧规则的 `scopeContent=false` 不会被自动纠正

第 2 项修复只改了新建规则的默认值。旧版本创建并保存过的规则，若 `scopeContent` 已存成 `false`，升级后依然不生效，用户需要手动进编辑页勾选「内容」再保存。

是否在 `ReplaceRuleRepository` 加载时做一次迁移（例如把 scope 三项全为 `false` 的规则视为正文规则）属于对已有数据做语义变更，尚未实施。需要产品侧确认：是自动迁移，还是仅在列表上给出提示。

### B. 规则试跑面板的键盘遮挡

`RuleTestSheet()` 的 `TextArea` 固定高度 140（`entry/src/main/ets/pages/ProfileSubPages.ets:715` 的 `.height(140)`），配合 `bindSheet` 的 `SheetSize.MEDIUM`，键盘弹出时「清空」「试跑」两个按钮被挤出可视区，必须先收起键盘才能点到。功能本身可用（模拟器上用返回键收键盘后测试通过），但真机上用户可能困惑。

未修复原因：属于布局调整，需要重新做整页 UI 验收，不在本次缺陷修复范围内。

### C. 分组删除在两处入口行为不一致

规则列表页菜单的「分组管理」已经能用：`entry/src/main/ets/data/ReplaceRuleRepository.ets:300` 的 `removeGroup()` 会把该分组下的规则回落到默认分组并清除分组记录，`entry/src/main/ets/pages/Index.ets:390` 的 `removeReplaceRuleGroup()` 已接上，面板内删除按钮走 `onRemoveGroup(group)`（`entry/src/main/ets/pages/ProfileSubPages.ets:304`）。

但编辑页另有一套独立的 `GroupManagerSheet`（`entry/src/main/ets/pages/ProfileSubPages.ets:865`），它的「删除选中」仍是占位实现：

```ts
this.onUnavailableAction('分组删除尚未迁移，未删除任何分组');
```

**影响**：同一功能两个入口，列表页可用、编辑页不可用，用户会认为分组删除坏了。

**成因**：编辑页的分组面板是在列表页分组面板之前写的，后续实现 `removeGroup` 时只接了列表页那套，编辑页这套没有跟着改。

**状态**：未修复。属于遗留缺陷，需要决定是让编辑页复用列表页的实现，还是直接移除编辑页这套重复面板。

### D. 替换规则不支持在线 URL 导入

上游 `ReplaceRuleScreen.kt` 的 `FilePickerSheet` 提供「选择系统文件 / 手动输入（含在线 URL）」两条路径。本地已实现本地文件选择与手动粘贴 JSON 文本，但没有从 URL 拉取规则的能力。

**原因**：本模块 `module.json5` 未声明 INTERNET 权限，全仓无网络客户端代码。这不是遗漏，是与「在线服务未接入」的整体边界一致。若后续接入在线服务，需重新审核权限与隐私说明。

## 验证环境的已知限制

以下不是应用缺陷，是验收手段的限制，记录在此避免后续误判：

- **退格键无效**：`uitest uiInput keyEvent 67` / `2050` 在 HOS 模拟器上不生效，无法用键盘清空 `TextInput`/`TextArea`，只能取消重进或依赖页面自带的「清空」按钮。
- **toast 抓取时机**：点击后立即 `dumpLayout` 常抓不到 toast 节点，需等待 1–2 秒再抓。
- **键盘收起**：`keyEvent 4` 在部分状态下不关闭软键盘，`keyEvent 2`（返回）更可靠。
- **长按菜单坐标**：长按菜单项位置随长按点变化，必须先 `dumpLayout` 定位再点击，不能复用固定坐标。
- **API 12 真机兼容未验证**：所有实测均在 OpenHarmony API 26 模拟器上完成，配置的 compatible/target SDK 是 HarmonyOS `5.0.0(12)`，模拟器运行不能证明 API 12 真机兼容。

## 相关文档

- 模块范围与验收状态见 [模块验收摘要](MODULE-STATUS.md)
- 构建与设备验证见 [验证记录](VALIDATION.md)
- 功能队列见 [项目队列](PROJECT.md)
