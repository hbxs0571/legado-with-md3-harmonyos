# HarmonyOS 开发文档

此目录包含可公开的项目说明、功能队列、模块说明和验收口径。实际进度以进度摘要与验证记录为准；本机续接记录、过程截图、备份和历史工作日志不包含在公开文档中。

| 主题 | 文档 |
| --- | --- |
| 功能优先顺序与边界 | [项目队列](PROJECT.md) |
| 当前公开进度 | [进度摘要](PROGRESS.md) |
| 模块边界（哪些验过、哪些没验） | [模块验收摘要](MODULE-STATUS.md) |
| 编码规约与已踩缺陷 | [编码规约](CODE-CONVENTIONS.md) |
| 盘点方法、验收等级与取证 / 判断 / 实现三段分工（验收只看输入干不干净） | [盘点规约](PARITY-RULES.md) |
| 移交前协作教训 | [E 端会话教训](E-SESSION-LESSONS.md) |
| 已知问题与验收边界 | [已知问题](KNOWN-ISSUES.md) |
| 模块入口与责任范围 | [模块概览](MODULES.md) |
| 本地阅读行为 | [阅读模块](READER.md) |
| Android ZIP 兼容范围 | [备份恢复](BACKUP-RESTORE.md) |
| ZIP 兼容度总账与盘点方法 | [ZIP 兼容总账](parity/STATUS.md)、[对照关键词](parity/KEYWORDS.md) |
| 书架 / 元数据 / 进度对照 | [书架对照表](parity/BOOKSHELF.md) |
| 书架布局对照 | [书架布局总账](parity/ZIP-BOOKSHELF-LAYOUT.md) |
| 书签 / 划线 / 笔记对照 | [书签对照表](parity/ZIP-BOOKMARK.md) |
| 阅读配置字段对照 | [阅读配置总账](parity/READER-CONFIG.md) |
| TXT 阅读链路对照 | [TXT 阅读总账](parity/TXT-READER.md) |
| 封面设置对照 | [封面设置总账](parity/ZIP-COVER.md) |
| 深色模式 / 主题设置对照 | [深色模式对照表](parity/ZIP-THEME.md) |
| UI 可用性验收 | [UI 验收口径](UI-PARITY.md) |
| 页面还原流程 | [UI 还原流程](UI-RESTORE.md) |
| 构建和验证记录 | [构建说明](BUILDING.md)、[验证记录](VALIDATION.md) |
| 核对脚本（七表计数、竖线体检、链接体检、锚点校验、证据包 lint） | `scripts/parity-rows.py`、`scripts/parity-pipes.py`、`scripts/doc-links.py`、`scripts/anchor-check.py`、`scripts/evidence-lint.py`（说明见 [盘点规约](PARITY-RULES.md) 第六节） |
| Hypium / UI 自动化测试 | [测试目标与运行说明](HYPIUM-UI-TEST.md) |
| 资源许可与来源 | [资源许可清单](RESOURCE-LICENSES.md)、[来源哈希表](RESOURCE-SOURCES-SHA256-2026-10-26.csv) |
| 资源公开范围 | [素材说明](ASSETS.md) |
| 术语 | [术语表](GLOSSARY.md) |
| 发行边界 | [开源与发行](RELEASE.md) |

本仓库是 HarmonyOS 工程的公开源码基线。功能队列表示优先级，不代表所有页面、数据格式或设备组合均已完成验收。
