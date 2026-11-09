# 阅读模块

本地阅读支持 TXT、EPUB、目录、分页、章节切换、阅读进度保存与恢复。阅读相关页面包括阅读器、阅读设置、目录、书内搜索和朗读设置；朗读服务尚未接入。

阅读设置源码包括系统字体选择、字体大小、段落/行距与字距、段首缩进、正文对齐、粗斜体、阴影和下划线等。E 端 HOS 模拟器按[验证记录](VALIDATION.md)检查了系统字体冷启动、对齐行为和部分正文效果。源码提供 TTF/OTF 导入，但实际字体文件导入、CJK fallback、EPUB 字体和复杂排版仍待验。

正文高亮规则（r258）按 Android `HighlightRule` 的字段建立本地规则模型、Preferences 仓储和正则匹配引擎，在分页与连续滚动的渲染文本上按 UTF-16 区间应用字色、背景色及实线/虚线/波浪线/双线/删除线；同优先级时后序规则覆盖前序规则。规则只作用于本地章节正文全局规则，用户划线/笔记（`ReaderMarking`）保持独立并优先。它与书籍标签抽取规则（`HighlightTagRule`）不是同一能力。N 端已在 HOS 模拟器完成面板可达、创建、正文命中、启停、冷启读回、滚动模式连续滚动与删除七项闭环，并修复了滚动模式高亮不生效与条目启停文案不刷新；Android 规则预设导入已经接通（`data/ReaderHighlightRulePresets.ets` 内置 12 条，面板 `openPresets` / `applyPresets` 取用，`targetScope` 非正文的预设标为「标题规则，本地暂不执行」）；`highlightRule.json` 备份恢复、字体替换、字距行距与文字背景图（含九宫格）也已接通。仍未接入的是按排版 `configName` 绑定与标题规则的执行：`data/ReaderHighlightRuleEngine.ets:52`-`:55` 只接受 `targetScope` 0 与 2、并对 `configName` 非空的规则直接跳过。

本地阅读记录由会话、按日明细和按书汇总三层数据组成；旧版本地记录会迁移到会话层。E 端曾核验按记录日期的隔离样例、基础迁移和会话读回。真实跨午夜持久化和扫描修复仍未验（字数统计已在 r327 改读预存的 `chapter.wordCount`；别名归属与合并已接通，见 `pages/Index.ets:5946` 的 `checkReadRecordAlias` 与 `data/ReadRecordRepository.ets:894` 的 `saveAliasDecision`）。Android ZIP 的历史记录已在 `entry/src/main/ets/data/BackupRepository.ets:1487`-`:1490` 映射进原生三层仓储，不再是「仅归档」。

阅读改动应核对当前书目、章节和位置的保存恢复，以及受影响的目录、搜索、控制层与设置。没有设备验证时，应将范围标记为未验证；构建成功不代表设备行为已验收。

当前状态见[进度摘要](PROGRESS.md)、[模块状态](MODULE-STATUS.md)和[验证记录](VALIDATION.md)。
