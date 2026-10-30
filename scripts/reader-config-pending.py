#!/usr/bin/env python3
"""盘点 docs/parity/READER-CONFIG.md 里状态为「未接」的行。

用途：
  1. 默认把每个未接行连同归属块、块内序号、各列内容输出为 JSON，供
     写 docs/KNOWN-ISSUES.md 登记条目时逐条引用。
  2. --apply-markers 时给每行的「备注」列补上 `见 KI-<块>-<序号>`，
     避免文档里留下裸的「未接」。

判据：明细表每行固定 7 列（上游能力 / 上游位置 / 本地位置 / 状态 /
差异说明 / 验收方式 / 备注），状态列恰为「未接」才算。
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

DOC = Path(__file__).resolve().parent.parent / "docs/parity/READER-CONFIG.md"
BLOCK_RE = re.compile(r"^## ([A-G]) ")


def cells(line: str) -> list[str]:
    parts = line.strip().strip("|").split("|")
    return [p.strip() for p in parts]


def scan() -> tuple[list[dict], list[str]]:
    lines = DOC.read_text(encoding="utf-8").splitlines()
    rows: list[dict] = []
    block = ""
    seq_by_block: dict[str, int] = {}
    for idx, line in enumerate(lines):
        m = BLOCK_RE.match(line)
        if m:
            block = m.group(1)
            seq_by_block.setdefault(block, 0)
            continue
        if not line.startswith("| ") or "未接" not in line:
            continue
        cs = cells(line)
        if len(cs) != 7 or cs[3] != "未接":
            continue
        seq_by_block[block] += 1
        seq = seq_by_block[block]
        rows.append(
            {
                "id": f"{block}-{seq:02d}",
                "block": block,
                "line": idx + 1,
                "title": cs[0],
                "upstream": cs[1],
                "local": cs[2],
                "diff": cs[4],
                "accept": cs[5],
                "note": cs[6],
            }
        )
    return rows, lines


def apply_markers(rows: list[dict], lines: list[str]) -> int:
    changed = 0
    for row in sorted(rows, key=lambda r: r["line"], reverse=True):
        idx = row["line"] - 1
        cs = cells(lines[idx])
        mark = f"见 KI-{row['id']}"
        cs[6] = mark if cs[6] in ("—", "") else f"{cs[6]}；{mark}"
        lines[idx] = "| " + " | ".join(cs) + " |"
        changed += 1
    DOC.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return changed


def main() -> int:
    rows, lines = scan()
    if "--apply-markers" in sys.argv:
        print(f"已给 {apply_markers(rows, lines)} 行补备注标记", file=sys.stderr)
    counts: dict[str, int] = {}
    for row in rows:
        counts[row["block"]] = counts.get(row["block"], 0) + 1
    payload = json.dumps({"total": len(rows), "byBlock": counts, "rows": rows}, ensure_ascii=False, indent=1)
    if "--out" in sys.argv:
        # 写文件而不是走 stdout：Windows 控制台会把中文转成 GBK，重定向后无法再解析
        out = Path(sys.argv[sys.argv.index("--out") + 1])
        out.write_text(payload, encoding="utf-8")
        print(f"已写入 {out}", file=sys.stderr)
        return 0
    print(payload)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
