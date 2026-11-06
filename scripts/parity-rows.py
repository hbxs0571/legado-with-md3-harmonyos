# -*- coding: utf-8 -*-
"""对照表核算器：七张 parity 表的行数与状态统计。

把原先散在 tmp/ 里的 mainrows2.py / zc_rows.py / rr_rows.py / na_rows.py
合并成一个可传参的脚本。四个脚本的切列逻辑本来一模一样，差别只在「按什么筛行」，
这里用 --file / --block / --category / --state 组合出来。

用法（在仓库根或任意目录跑都行，默认按本文件位置推断仓库）：
    python tmp/lib/parity_rows.py                      # 七表总览（每表一行汇总）
    python tmp/lib/parity_rows.py --detail             # 再加每块的 A/B/C 拆分
    python tmp/lib/parity_rows.py --file ZIP-COVER.md --list     # 列出该表每行状态
    python tmp/lib/parity_rows.py --file ZIP-COVER.md --state 未接 --list
    python tmp/lib/parity_rows.py --category readRecord --list   # 按第 9 列 ZIP 类别筛
    python tmp/lib/parity_rows.py --block A1 --list    # 只统计 A1 块

口径（与 docs/PARITY-RULES.md 一致，改口径前先读第二节）：
- 单元格里的 `\\|` 是字面竖线，不是列分隔符；必须逐字符扫，不能 line.split('|')
- 状态列前缀匹配：`已接（仅配置页）` 按 `已接` 计（ZIP-BOOKMARK 有两行是这种）
- 表头行（首列 `上游能力` / `块` / `类别键名` / `表头` / `记号`）与全 `-:` 分隔行不算数据
- 只统计 `## A`–`## G` 正文块下的行；文件头的「盘面」小节不算
"""
import argparse
import io
import os
import re
import sys
from collections import Counter, OrderedDict

BS, PIPE = chr(92), '|'
STATES = ('已接', '未接', '不适用', '待定')
HEADER_FIRST_CELLS = ('上游能力', '块', '类别键名', '表头', '记号')


def default_repo_root():
    """本文件在 <repo>/tmp/lib/ 下时，repon 上两级；否则退到当前目录。"""
    here = os.path.dirname(os.path.abspath(__file__))
    guess = os.path.dirname(os.path.dirname(here))
    if os.path.isdir(os.path.join(guess, 'docs', 'parity')):
        return guess
    return os.getcwd()


def split_cells(line):
    """按未转义的竖线切列；`\\|` 还原成字面竖线。"""
    out, cur, i = [], [], 0
    n = len(line)
    while i < n:
        ch = line[i]
        if ch == BS and i + 1 < n and line[i + 1] == PIPE:
            cur.append(PIPE)
            i += 2
            continue
        if ch == PIPE:
            out.append(''.join(cur))
            cur = []
            i += 1
            continue
        cur.append(ch)
        i += 1
    out.append(''.join(cur))
    return out


def status_of(cells):
    """状态列前缀匹配，返回规范状态名或 None。"""
    fallback = None
    for c in cells:
        v = c.strip()
        for st in STATES:
            if v == st:
                return st
            if v.startswith(st + '（') or v.startswith(st + '('):
                if fallback is None:
                    fallback = st
    return fallback


def is_divider(cells):
    return all(re.fullmatch(r'-+:?', c.replace(' ', '')) for c in cells if c)


def scan_file(path):
    """返回 [(行号, 块名, 状态, 首列能力名, 原始 cells)]。"""
    rows = []
    block = ''
    for idx, line in enumerate(io.open(path, encoding='utf-8').read().split('\n'), 1):
        if line.startswith('## ') or line.startswith('### '):
            block = line.strip('# \n')
            continue
        if not line.startswith(PIPE):
            continue
        cells = split_cells(line)
        if len(cells) < 4 or is_divider(cells):
            continue
        head = cells[0].replace('*', '').strip()
        if head in HEADER_FIRST_CELLS:
            continue
        st = status_of(cells)
        if not st:
            continue
        if not re.match(r'^[A-Z]\d?\b', block):
            continue
        rows.append((idx, block, st, cells[1].strip(), cells))
    return rows


def category_of(cells):
    """ZIP 类别列：8 列表取第 9，10 列表取第 9，兜底扫全行找 backtick 词。"""
    for c in cells[8:9]:
        v = c.strip().strip('`')
        if v:
            return v
    return ''


def top_block(block):
    """`A1 书架主屏与卡片` -> `A1`；`A 规则层` -> `A`。"""
    m = re.match(r'^([A-G]\d?)', block)
    return m.group(1) if m else block


def main(argv=None):
    ap = argparse.ArgumentParser(description='parity 对照表核算器')
    ap.add_argument('--repo', default=None, help='仓库根（默认按本文件位置推断）')
    ap.add_argument('--file', default=None, help='只看某一支表，如 ZIP-COVER.md')
    ap.add_argument('--block', default=None, help='只看某块，如 A1 / B / C')
    ap.add_argument('--category', default=None, help='按 ZIP 类别列筛，如 readRecord')
    ap.add_argument('--state', default=None, help='只看某状态：已接 / 未接 / 不适用')
    ap.add_argument('--list', action='store_true', help='逐行打印（默认只打汇总）')
    ap.add_argument('--detail', action='store_true', help='汇总模式下再打每块拆分')
    args = ap.parse_args(argv)

    root = args.repo or default_repo_root()
    parity = os.path.join(root, 'docs', 'parity')
    if not os.path.isdir(parity):
        print('找不到 %s，用 --repo 指定仓库根' % parity, file=sys.stderr)
        return 2

    names = [args.file] if args.file else sorted(
        n for n in os.listdir(parity) if n.endswith('.md'))

    grand = Counter()
    for name in names:
        path = os.path.join(parity, name)
        if not os.path.isfile(path):
            print('没有这个文件：%s' % path, file=sys.stderr)
            return 2
        rows = scan_file(path)
        if args.block:
            rows = [r for r in rows if top_block(r[1]) == args.block]
        if args.category:
            rows = [r for r in rows if args.category in category_of(r[4])]
        if args.state:
            rows = [r for r in rows if r[2] == args.state]
        if not rows:
            if args.file:
                print('%s：0 行（口径筛空了）' % name)
            continue

        tot = Counter(r[2] for r in rows)
        grand.update(tot)
        print('%-26s %4d  %s' % (name, len(rows), dict(tot)))

        if args.detail:
            blocks = OrderedDict()
            for idx, blk, st, _, _ in rows:
                blocks.setdefault(blk, Counter())[st] += 1
            for blk, cnt in blocks.items():
                print('    %-38s %3d  %s' % (blk, sum(cnt.values()), dict(cnt)))

        if args.list:
            for idx, blk, st, ability, cells in rows:
                cat = category_of(cells)
                print('  :%d\t%-3s\t%-4s\t%s\t%s' % (idx, blk, st, ability[:36], cat))

    if not args.file:
        print('-' * 60)
        print('合计 %d 行 = 已接 %d / 未接 %d / 不适用 %d / 待定 %d'
              % (sum(grand.values()), grand['已接'], grand['未接'],
                 grand['不适用'], grand['待定']))
    return 0


if __name__ == '__main__':
    sys.exit(main())
