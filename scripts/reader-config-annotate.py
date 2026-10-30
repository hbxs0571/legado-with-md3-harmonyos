#!/usr/bin/env python3
"""把 READER-CONFIG.md 明细表里每一行「未接」的备注列补上 KI 锚点。

锚点指向 docs/KNOWN-ISSUES.md「阅读配置行登记」节里的登记组。
映射写死在 GROUPS 里：键是行 id（由 reader-config-pending.py 的编号规则生成），
值是 KI 组编号。未接行必须且只能落到一个组，脚本会校验覆盖完整性。
"""

from __future__ import annotations

import sys
from pathlib import Path

DOC = Path(__file__).resolve().parent.parent / "docs/parity/READER-CONFIG.md"

# A 块
GROUPS: dict[str, str] = {}
for i in range(1, 5):
    GROUPS[f"A-{i:02d}"] = "KI-A1"
for i in (5, 8, 17):
    GROUPS[f"A-{i:02d}"] = "KI-A2"
GROUPS["A-06"] = "KI-A3"
GROUPS["A-07"] = "KI-A4"
for i in (9, 10, 11):
    GROUPS[f"A-{i:02d}"] = "KI-A5"
GROUPS["A-12"] = "KI-A6"
for i in (13, 15):
    GROUPS[f"A-{i:02d}"] = "KI-A7"
GROUPS["A-14"] = "KI-A8"
GROUPS["A-16"] = "KI-A9"
GROUPS["A-18"] = "KI-A10"
for i in (19, 20):
    GROUPS[f"A-{i:02d}"] = "KI-A11"
GROUPS["A-21"] = "KI-A12"
# C 块
for i in range(1, 4):
    GROUPS[f"C-{i:02d}"] = "KI-C1"
for i in range(4, 7):
    GROUPS[f"C-{i:02d}"] = "KI-C2"
for i in range(7, 11):
    GROUPS[f"C-{i:02d}"] = "KI-C3"
for i in range(11, 25):
    GROUPS[f"C-{i:02d}"] = "KI-C4"
GROUPS["C-25"] = "KI-C5"
GROUPS["C-26"] = "KI-C6"
# D 块
for i in (1, 3):
    GROUPS[f"D-{i:02d}"] = "KI-D1"
for i in (2, 8, 9):
    GROUPS[f"D-{i:02d}"] = "KI-D2"
GROUPS["D-04"] = "KI-D3"
GROUPS["D-05"] = "KI-D4"
for i in (6, 7):
    GROUPS[f"D-{i:02d}"] = "KI-D5"
GROUPS["D-10"] = "KI-D6"
# E 块
for i in range(1, 10):
    GROUPS[f"E-{i:02d}"] = "KI-E1"
for i in range(10, 17):
    GROUPS[f"E-{i:02d}"] = "KI-E2"
for i in range(17, 21):
    GROUPS[f"E-{i:02d}"] = "KI-E3"
for i in range(21, 28):
    GROUPS[f"E-{i:02d}"] = "KI-E4"
for i in range(28, 36):
    GROUPS[f"E-{i:02d}"] = "KI-E5"
for i in range(36, 41):
    GROUPS[f"E-{i:02d}"] = "KI-E6"


def cells(line: str) -> list[str]:
    return [p.strip() for p in line.strip().strip("|").split("|")]


def main() -> int:
    import re

    block_re = re.compile(r"^## ([A-G]) ")
    lines = DOC.read_text(encoding="utf-8").splitlines()
    block = ""
    seq: dict[str, int] = {}
    touched = 0
    for idx, line in enumerate(lines):
        m = block_re.match(line)
        if m:
            block = m.group(1)
            seq.setdefault(block, 0)
            continue
        if not line.startswith("| ") or "未接" not in line:
            continue
        cs = cells(line)
        if len(cs) != 7 or cs[3] != "未接":
            continue
        seq[block] += 1
        row_id = f"{block}-{seq[block]:02d}"
        group = GROUPS.get(row_id)
        if group is None:
            print(f"缺少映射：{row_id}（第 {idx + 1} 行）", file=sys.stderr)
            return 1
        mark = f"见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) {group}"
        if mark in cs[6]:
            continue
        cs[6] = mark if cs[6] in ("—", "") else f"{cs[6]}；{mark}"
        lines[idx] = "| " + " | ".join(cs) + " |"
        touched += 1
    DOC.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"已补 {touched} 行的 KNOWN-ISSUES 锚点，映射共 {len(GROUPS)} 行", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
