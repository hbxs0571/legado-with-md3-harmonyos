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

### 3. 旧规则的 `scopeContent=false` 不会自动纠正

**现象**：第 2 项修复只改了新建规则的默认值。旧版本创建并保存过的规则，若 `scopeContent` 已存成 `false`，升级后依然不生效，用户需要手动进编辑页勾选「内容」再保存。

**修复**：在加载时做一次迁移。`entry/src/main/ets/data/ReplaceRuleRepository.ets:104` 的 `needsScopeMigration()` 把「标题与正文都不生效」的规则判定为上述历史缺陷遗留，加载后补成正文规则并写回存储：

```ts
private static needsScopeMigration(rule: ReplaceRule): boolean {
  return rule.scopeTitle === false && rule.scopeContent === false;
}
```

判定依据是上游 `ReplaceRule.scopeContent` 默认为 `true`，一条标题与正文都不作用的规则在语义上没有意义。只动这一类，用户显式只勾「标题」的规则不受影响。

### 4. 编辑页的分组面板点不开

**现象**：在规则编辑页点分组右侧的齿轮图标没有任何反应，面板不弹出。

**成因**：编辑页对**同一个根组件**连续绑定了两个 `bindSheet`：

```ts
.bindSheet(this.showGroupManager, this.GroupManagerSheet(), {...})
.bindSheet(this.showTestPanel, this.RuleTestSheet(), {...})
```

ArkUI 一个组件只能绑定一个半模态页面，后绑定的会覆盖先绑定的。所以 `showGroupManager` 状态确实变成了 `true`，但页面没有挂载。试跑面板能弹出、分组面板不能，正是因为试跑面板是后绑定的那个。

这个写法在引入试跑面板时就已经存在，也就是说编辑页的分组面板从那时起一直是失效的。

**修复**：合并成一个 `bindSheet`，用 `activeSheet` 状态切换内容，与本仓库 `entry/src/main/ets/pages/ProfileSubPages.ets:2634` 读记录面板的既有写法一致：

```ts
@State activeSheet: string = '';   // '' / 'group' / 'test'

.bindSheet(this.activeSheet.length > 0, this.EditPageSheet(), {...})
```

`EditPageSheet()` 内按 `activeSheet` 分支调用 `GroupManagerSheet()` 或 `RuleTestSheet()`。

**验证**：齿轮能打开分组面板；试跑面板仍从「更多 → 测试规则」正常打开，两者互不干扰。

### 5. 分组面板内增删改后列表不刷新

**现象**：修复第 4 项后分组面板能打开了，但在面板里新增分组，列表不出现；删除分组，行不消失。关闭面板再打开才看得到变化（删除本身是生效的，重启应用后确实没了）。

**成因**：面板是 `bindSheet` 的 builder 内容，**面板打开期间 builder 不会重新执行**，所以 `groups: this.availableGroups()` 这个入参永远停在打开那一刻的值，`@Prop` 收不到新值。

**修复**：让面板自己持有列表，操作后从仓储重取。`entry/src/main/ets/pages/ProfileSubPages.ets:964` 的 `ReplaceRuleGroupSheet`：

- 新增 `@State localGroups`，`aboutToAppear()` 与每次增删改后调 `reloadGroups()`（仓储是内存缓存，直接读不产生额外 IO）
- 分组回调类型由 `(name: string) => void` 改为返回 `Promise<void>`，面板 `await` 落盘完成后再刷新

**为什么不用固定延时**：最初用 `setTimeout(..., 120)` 等异步落盘，实测仍偶发不刷新。改为等 Promise 才是确定的。

**验证**：新增 GrpY 后立即出现在列表；删除 GrpY 后行立即消失；把 GrpX 重命名为 GrpXZ 后列表立即更新，输入框同时复位为「添加」态。

## 对齐上游补齐的交互

以下不是缺陷修复，是把本地实现补齐到上游 Android 的行为。上游依据均为 `app/src/main/java/io/legado/app/ui/replace/` 下的源码。

### 6. 选择模式缺少「反选」

**上游**：`ReplaceRuleScreen.kt:275` 的 `onSelectInvert` 调用 `ReplaceRuleViewModel.kt:390` 的 `invertSelection()`，实现为「当前列表全部 id 减去已选 id」。

**本地实现**：`entry/src/main/ets/pages/ProfileSubPages.ets:236` 的 `invertSelection()`，同样在**当前筛选结果**内取差集，而不是全部规则——保证「反选」与用户眼前列表范围一致。

**验证**：选中 0 项时点反选变成「已选择 2 项」；再点一次回到「已选择 0 项」。

### 7. 批量删除没有二次确认

**上游**：`RuleListScaffold.kt:75-86` 用 `AppAlertDialog` 弹确认框，标题 `R.string.delete`、正文 `R.string.sure_del`。

**本地实现**：新增 `pendingDeleteIds` 状态与 `confirmDelete` / `cancelDelete` 方法（`entry/src/main/ets/pages/ProfileSubPages.ets:426-453`）。确认面板与长按菜单的单条删除**共用**同一个面板，避免两条删除路径行为不一致。批量删除确认后仍退出选择模式，单条删除则保留选择模式并从选中集合里摘掉该条。

`bindSheet` 高度改为条件式：确认面板只有几行文字，用 `SheetSize.FIT_CONTENT` 避免半屏空白；其余面板保持 `SheetSize.MEDIUM`（`entry/src/main/ets/pages/ProfileSubPages.ets:618`）。

**验证**：全选 2 条点删除 → 面板显示「确定删除选中的 2 条替换规则？删除后可通过导入恢复。」；点「取消」规则仍在、选中态保留；点「删除」存储写入 `rules_v1=[]`、列表显示「暂无替换净化规则」、选择模式退出。

### 8. 长按菜单缺少「删除」

**上游**：`ReplaceRuleScreen.kt:463-482` 的条目下拉是置顶 `R.string.move_to_top`、置底 `R.string.move_to_bottom`、删除 `R.string.delete` 三项。

**本地实现**：`entry/src/main/ets/pages/ProfileSubPages.ets:288` 的 `RuleRowMenu()` 补上第三项「删除」，走同一个 `requestDelete([rule.id])`。

**验证**：长按条目弹出三项；点删除 → 确认面板显示单条文案「确定删除这条替换规则？删除后可通过导入恢复。」；确认后存储只剩另一条规则，`order` 重排为 0。

### 9. 选择模式缺少「导出选中」

**上游**：`ReplaceRuleScreen.kt:322-325` 的 `ActionItem(text=导出)`。

**本地实现**：`entry/src/main/ets/pages/ProfileSubPages.ets:456` 的 `submitBatchExport()`，从 `rules` 过滤出选中项后调 `onExportRules`，未选中时提示「请先选择规则」而不是静默无反应。

**验证**：全选 2 条点导出 → 系统保存对话框默认文件名 `replaceRules-<时间戳>.json`；保存后设备 `Documents/replaceRules-1793109799610.json` 内容为只含这 2 条的格式化 JSON，字段与本地存储一致；导出前后 `rules_v1` 存储内容不变（导出是只读操作）。

**未采纳**：上游的批量导入预览勾选对话框（`BatchImportDialog`）。本地导入是「解析后直接合并 + toast 报告新增/更新/跳过条数」（`entry/src/main/ets/pages/Index.ets:525` 的 `importReplaceRules`），路径不同但可用，重做会推翻已验证流程。

## 遗留风险（待决策）

### A. 规则试跑面板的键盘遮挡

`RuleTestSheet()` 的 `TextArea` 固定高度 140（`entry/src/main/ets/pages/ProfileSubPages.ets:715` 的 `.height(140)`），配合 `bindSheet` 的 `SheetSize.MEDIUM`，键盘弹出时「清空」「试跑」两个按钮被挤出可视区，必须先收起键盘才能点到。功能本身可用（模拟器上用返回键收键盘后测试通过），但真机上用户可能困惑。

未修复原因：属于布局调整，需要重新做整页 UI 验收，不在本次缺陷修复范围内。

### B. 替换规则不支持在线 URL 导入

上游 `ReplaceRuleScreen.kt` 的 `FilePickerSheet` 提供「选择系统文件 / 手动输入（含在线 URL）」两条路径。本地已实现本地文件选择与手动粘贴 JSON 文本，但没有从 URL 拉取规则的能力。

**原因**：本模块 `module.json5` 未声明 INTERNET 权限，全仓无网络客户端代码。这不是遗漏，是与「在线服务未接入」的整体边界一致。若后续接入在线服务，需重新审核权限与隐私说明。

## 验证环境的已知限制

以下不是应用缺陷，是验收手段的限制，记录在此避免后续误判：

- **退格键无效**：`uitest uiInput keyEvent 67` / `2050` 在 HOS 模拟器上不生效，无法用键盘清空 `TextInput`/`TextArea`，只能取消重进或依赖页面自带的「清空」按钮。
- **toast 抓取时机**：点击后立即 `dumpLayout` 常抓不到 toast 节点，需等待 1–2 秒再抓。
- **键盘收起**：`keyEvent 4` 在部分状态下不关闭软键盘，`keyEvent 2`（返回）更可靠。
- **长按菜单坐标**：长按菜单项位置随长按点变化，必须先 `dumpLayout` 定位再点击，不能复用固定坐标。
- **API 12 真机兼容未验证**：所有实测均在 OpenHarmony API 26 模拟器上完成，配置的 compatible/target SDK 是 HarmonyOS `5.0.0(12)`，模拟器运行不能证明 API 12 真机兼容。
- **bindSheet 内容不随父级重建**：面板打开期间 builder 不会重新执行，验证「操作后列表是否刷新」这类行为必须真实点一次操作，不能只看关闭再打开的结果。

## 相关文档

- 模块范围与验收状态见 [模块验收摘要](MODULE-STATUS.md)
- 构建与设备验证见 [验证记录](VALIDATION.md)
- 功能队列见 [项目队列](PROJECT.md)
