# 文档迁移报告

迁移日期：2026-10-28
入口文档：`MIGRATION.md`
源工程：`legado-n-transfer-2026-10-28-r258/unpacked/src01/legado-with-MD3/harmonyos`
目标工程：`N:\HarmonyProjects\legado-with-md3-harmonyos`

## 一、复制范围

| 类别 | 数量 | 说明 |
| --- | --- | --- |
| `docs/` 下 Markdown | 190 篇 | 源 `docs/` 全部 md，含未被链接到的历史日志 |
| 入口文件 | 1 个 | `MIGRATION.md` |
| 闭包内图片/CSV | 34 个 | 被文档实际引用的证据截图与资源清单 |
| 文档同目录 assets | 35 个 | `docs/history/evidence/assets/` 等目录下被引用的图片 |
| `reader-information-settings/` | 10 个 | 整目录复制（截图 + 布局树 JSON，3.3 MB） |
| 从 02 私有素材包解压 | 318 个 | 正文提到的 `project-resources` 素材，73.8 MB |

`docs/` 现有 265 个文件，本地 `project-resources/` 现有 351 个文件（92 MB）。

## 二、同名冲突处理

以下 12 个文件源端与本地内容不同。**本地公开版未被覆盖**，源端 E 版另存到 `docs/e-reference/`：

`ASSETS.md`、`BACKUP-RESTORE.md`、`GLOSSARY.md`、`HYPIUM-UI-TEST.md`、`INDEX.md`、`KNOWN-ISSUES.md`、`MODULES.md`、`PROJECT.md`、`READER.md`、`RELEASE.md`、`UI-PARITY.md`、`VALIDATION.md`

原因：源端版本含 E 端盘符绝对路径并链接到 `docs/CURRENT.md`、`docs/history/`，属私有工作副本；本地版是已脱敏的公开文档体系。

`docs/e-reference/` 已加入 `.gitignore`，**不随仓库提交**：该目录是 E 端文档逐字快照，正文含设备地址 `127.0.0.1:5555`、真实书名与 `E:/开发/...` 构建日志路径，属于本机对照材料而非公开文档。文件保留在磁盘上供本地查证，但公开仓库里不会出现。`docs/dev/` 同理（开发计划含 E 盘备份路径）。

## 三、链接重写

### 3.1 Markdown 链接

| 处理类型 | 数量 |
| --- | --- |
| 已是正确相对链接（无需改动） | 274 |
| 重写为正确本地路径 | 34 |
| 保留外部 URL / 锚点 | 23 |
| 断链 | **0** |

重写规则：

1. E 端盘符绝对路径 → 相对本地文件路径
2. `../../../../../project-resources/...`（多一层 `../`）→ `../../../../project-resources/...`
3. `assets/xxx.png` 实为文档同目录 `assets/` 子目录 → 补齐文件后保持原相对写法
4. `project-records/` 下原本指向同级 `CURRENT.md` 的链接 → 上溯两级指向 `docs/CURRENT.md`（真实位置）
5. 指向 `backups/legado-harmonyos-book-progress-before-fix-20261026.xml` 的链接，该文件在 01/02/03 三个转移包中均不存在 → 改为文字标注「E 端设备备份，未随转移包」

### 3.2 正文绝对路径

| 处理类型 | 数量 |
| --- | --- |
| E 端盘符路径出现次数 | 514（31 个文件） |
| 改写为本机 N 端路径后本地存在 | 483 |
| 改写后本地仍缺失 | 31 |
| 改写后残留 E 端路径 | **0** |

仍缺失的 31 处（已在文档中保留 N 端路径，但文件本身未随包提供）：

- `backups\*.zip` 20 处 — E 端源码备份归档
- `legado-with-MD3\app`、`legado-with-MD3` 等 11 处 — Android 源工程路径描述

## 四、工程路径修正

`N:\HarmonyProjects\legado-with-MD3\harmonyos` 在本机不存在（本地工程名为 `legado-with-md3-harmonyos`），已把 11 处改为 `N:\HarmonyProjects\legado-with-md3-harmonyos`。

另有 5 处保留 `N:\HarmonyProjects\legado-with-MD3`：这些是「仓库 + 子工程」两层结构的描述，且该目录在本机真实存在（Android 源项目）。

## 五、校验结果

迁移当日（2026-10-28）校验：Markdown 本地链接 308 条全部有效，0 断链；正文 E 盘路径 0 残留；外部链接 23 条原样保留。

**2026-10-29 复跑**（`docs/e-reference/`、`docs/dev/` 加入 `.gitignore` 之后）：

| 项 | 结果 |
| --- | --- |
| 本地链接有效 | 326 |
| 断链 | **0** |
| 外部链接 / 锚点 | 23 |
| 正文 `E:\HarmonyProjects` 残留 | 0 |

有效链接数从 308 升到 326，是期间新增 `docs/UI-RESTORE.md` 与 `docs/INDEX.md` 索引行带来的，不是迁移遗漏。`e-reference/` 与 `dev/` 加入忽略后**断链数仍为 0**：忽略只影响是否提交，文件仍在磁盘上，链接照常可解析；同时提交范围内的文档没有任何一条指向这两个目录的 Markdown 链接（`docs/MIGRATION-REPORT.md` 中提及 `docs/e-reference/` 是行内代码，不是链接）。

## 六、复现脚本

迁移过程脚本保留在 `N:\HarmonyProjects\tmp\`：

| 脚本 | 作用 |
| --- | --- |
| `copy_docs.py` | 复制 docs 与闭包素材，冲突文件另存 e-reference |
| `scan_private_refs.py` | 扫描文档中对 02 包素材的引用 |
| `extract_assets.py` | 按清单从 02 包解压素材 |
| `backfill.py` | 从源工程补齐文档同目录的 assets 文件 |
| `rewrite_links.py` | 重写 Markdown 链接为本机相对路径 |
| `rewrite_epaths.py` | 把正文 E 盘绝对路径改写为 N 盘 |
| `verify_all.py` | 全量链接校验与 E 路径残留检查 |
