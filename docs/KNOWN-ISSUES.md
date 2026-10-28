# 已知问题与验收边界

更新：2026-10-28。以下仅列出公开源码和 E 端记录能够支持的状态，不包含测试书名、个人文件名、设备地址、日志或截图。

## 书架与分组

- r250 的全局排序档位和分组 `bookSort` 覆盖逻辑已接入；E 端尚未使用多本书和多组分组逐档核对真实列表顺序。
- 书架布局九字段的 Android ZIP 差异值往返、外部 Android ZIP 分组导入导出尚未完成 E 端设备验收。
- r256 已验证隐藏页签后从分组管理切换到“本地未分组”并在冷启动后保留；没有自定义分组的设备场景未覆盖自定义筛选项。
- 分组卡片的拖拽排序、封面实际选择/冷启动读回仍未验。
- `isPrivate` 只保存兼容标记，不提供访问保护；`enableRefresh` 不控制分组更新。r257 已将这两项 UI 文案明确为未生效/未接入。

## Android ZIP 兼容

- r255 已在 E 端 HOS 模拟器验证 `readConfig × themeConfig` 两类别各自包含或忽略的四种组合，阅读设置与护眼六键按相应类别恢复或保留。
- `bookGroup.json` 的备份导出和恢复导入代码路径已接入；仍需验证外部 Android ZIP、冲突合并和完整设备往返。
- 书架布局类别已有九字段写入/恢复路径，但没有用九个不同哨兵值逐项验证。真实 Android ZIP 的完整兼容范围尚未验收。
- 阅读记录会话、按日明细和按书汇总已由原生本地仓储承载；Android ZIP 中的 `readRecord.json`、`readRecordDetail.json`、`readRecordSession.json` 仍仅作兼容归档保留，不导入原生阅读记录。
- ZIP 兼容不代表完整 Android 数据库迁移、跨类别事务回滚、凭据恢复或正文打包。

## 阅读与规则

- 阅读设置尚未逐控件完成回归。系统字体选择已检查；自定义 TTF/OTF 实际导入、CJK fallback、EPUB 字体和多设备排版仍待验证。
- 阅读记录真实跨午夜持久化、损坏数据扫描/修复提示、阅读字数采集和书籍别名合并仍未完成或未验。
- TXT 目录规则完整 CRUD/批量组合和含非空规则的应用备份恢复仍需补测。
- 替换规则的同步正则未受 `timeoutMillisecond` 限时；异步并发保存覆盖风险、完整恢复提示仍待验证。
- 在线 URL 规则导入、在线书源抓取、RSS、TTS、AI、WebDAV、云同步和 Web 服务未接入。
- `config.xml` 骨架只写空 `<map>` 后，曾有 24 个阅读配置键（`readStyleSelect`、`shareLayout`、`hideStatusBar`、`hideNavigationBar`、`readingAnchorEnabled`、`swipeToAddBookmark`、`maxLengthWithNoToc`、`readMenuIconShowText`、`readMenuIconStyle`、`readMenuIconItemsPerRow`、`readMenuIconRowCount`、`progressBarBehavior`、`tocUiUseReplace`、`tocCountWords`、`clickImgWay`、`clickActionTopLeft` 至 `clickActionBottomRight`）原先只由骨架写出，`readConfig` 段没有补写，备份出的 `config.xml` 会缺这些键。已在 `readConfig` 段补齐并在 N 端模拟器核对：不排除时 55 键齐全，「排除阅读配置」时整段消失、只剩护眼六键与书架布局九键。

## 设备范围

- API 12 真机兼容尚未验证。HOS 模拟器检查只代表验证记录中列出的操作；N 端 API 26 数据不作为 E 端或 API 12 结论。
- r257 设备没有自定义分组，卡片上新增的私有标记/刷新状态文案未在设备上直接显示验证。

构建与设备记录见[验证记录](VALIDATION.md)，Android ZIP 字段边界见[备份恢复说明](BACKUP-RESTORE.md)。
