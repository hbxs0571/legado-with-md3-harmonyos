# -*- coding: utf-8 -*-
"""对照表竖线体检：找出「表格行单元格数与表头不一致」的行。

按列数解析的脚本（parity-rows.py 等）遇到少一列/多一列的行会整行丢弃，
于是总账少算行，而且不报错。这个脚本专门抓这种静默丢行。

用法：
    python scripts/parity-pipes.py                # 默认扫 docs/parity
    python scripts/parity-pipes.py --repo /path/to/repo
    python scripts/parity-pipes.py --file docs/parity/ZIP-COVER.md

退出码：0 = 没有不一致；1 = 有（打印文件、行号、表头列数、实际列数）。
"""
import argparse
import io
import os
import sys

BS, PIPE = chr(92), '|'


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


def is_divider(line):
    """`| --- | --- |` 这种分隔行。"""
    s = line.strip()
    if not s.startswith(PIPE):
        return False
    return all(ch in '-: |' for ch in s) and '-' in s


def default_repo_root():
    here = os.path.dirname(os.path.abspath(__file__))
    guess = os.path.dirname(here)
    if os.path.isdir(os.path.join(guess, 'docs', 'parity')):
        return guess
    return os.getcwd()


def scan(path):
    """返回 [(行号, 表头列数, 实际列数, 表头原文)]。"""
    bad = []
    lines = io.open(path, encoding='utf-8').read().split('\n')
    i = 0
    while i < len(lines):
        # 表头 = 当前行是 | ... |，下一行是分隔行
        if lines[i].strip().startswith(PIPE) and i + 1 < len(lines) and is_divider(lines[i + 1]):
            header = len(split_cells(lines[i].strip()))
            j = i + 2
            while j < len(lines) and lines[j].strip().startswith(PIPE):
                actual = len(split_cells(lines[j].strip()))
                if actual != header:
                    bad.append((j + 1, header, actual, lines[i].strip()[:160]))
                j += 1
            i = j
            continue
        i += 1
    return bad


def main(argv=None):
    ap = argparse.ArgumentParser(description='对照表竖线体检')
    ap.add_argument('--repo', default=None, help='仓库根（默认按本文件位置推断）')
    ap.add_argument('--file', action='append', default=None,
                    help='只查指定文件（可重复）；默认查 docs/parity 下全部 .md')
    args = ap.parse_args(argv)

    root = args.repo or default_repo_root()
    if args.file:
        targets = [f if os.path.isabs(f) else os.path.join(root, f) for f in args.file]
    else:
        parity = os.path.join(root, 'docs', 'parity')
        if not os.path.isdir(parity):
            print('找不到 %s，用 --repo 指定仓库根' % parity, file=sys.stderr)
            return 2
        targets = [os.path.join(parity, n) for n in sorted(os.listdir(parity))
                   if n.endswith('.md')]

    total_bad = 0
    for path in targets:
        if not os.path.isfile(path):
            print('没有这个文件：%s' % path, file=sys.stderr)
            return 2
        bad = scan(path)
        total_bad += len(bad)
        for line, header, actual, hdr_text in bad:
            print('%s:%d  表头 %d 列 / 实际 %d 列（差 %+d）'
                  % (os.path.relpath(path, root).replace('\\', '/'), line,
                     header, actual, actual - header))
            print('    表头：%s' % hdr_text)

    if total_bad:
        print('\n共 %d 行单元格数不一致。多一列通常是单元格里写了未转义的 |，'
              '少一列通常是行尾漏了 |。' % total_bad)
        return 1
    print('OK 所有表格行单元格数与表头一致')
    return 0


if __name__ == '__main__':
    sys.exit(main())
