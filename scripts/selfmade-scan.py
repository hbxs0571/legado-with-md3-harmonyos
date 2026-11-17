#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selfmade-scan.py —— 剥掉块注释与行注释后，扫描界面层里的「开发者口吻」文案。

这些词出现在用户可见的界面文案里属于自造/占位，不该留在交付物中；出现在注释里
则是合法的开发者说明，所以必须先剥注释、保持行号，再扫描。

用法：
  python scripts/selfmade-scan.py
  python scripts/selfmade-scan.py --roots entry/src/main/ets/pages
  python scripts/selfmade-scan.py --include-placeholders   # 宽口径排查，见下
  python scripts/selfmade-scan.py --extra-pattern '预览|暂不执行'

退出码：0 = 零命中；1 = 有命中（逐行打印 path:line: text 与总数）。

关于词表口径（批11 收口时厘清）：
  默认只扫任务书 11.1 判据3 的六个硬词。判据3 原文就是
  「上游|落库|仅展示|只做配置|无渲染效果|没有对应」；这六词出现在用户可见
  文案里即自造，必须归零。任务书 11.2 的脚本模板额外贴了
  「尚未迁移|尚未接入|暂不执行|界面预览」四词，那是批2 全仓排查用的宽口径
  （2.0 节扫出 351 行、真问题仅 26 条），不是归零判据：证据包 12.x 节已把这
  四词的命中逐条归为 R 类（平台事实/空状态）或 U 类（用户已批准的
  onUnavailableAction 占位），一律合法保留。若默认也扫这四词，验收会恒红。
  需要复查这些合法占位时显式加 --include-placeholders，命中不算失败口径。
"""

import argparse
import io
import pathlib
import re
import sys

# 归零判据词表，与任务书 11.1 判据3 一致（六个硬词）
DEFAULT_PATTERN = r'上游|落库|仅展示|只做配置|无渲染效果|没有对应'
# 宽口径额外词：批2 全仓排查用，命中多为合法占位，不参与归零判据
PLACEHOLDER_PATTERN = r'尚未迁移|尚未接入|暂不执行|界面预览'
DEFAULT_ROOTS = ['entry/src/main/ets/pages', 'entry/src/main/ets/components']


def strip_comments(src: str) -> str:
    """把块注释与行注释替换成空格，保留换行与行号。"""
    out = list(src)
    i, n = 0, len(src)
    in_block = False
    while i < n:
        if in_block:
            if src.startswith('*/', i):
                in_block = False
                out[i] = out[i + 1] = ' '
                i += 2
            else:
                if src[i] != '\n':
                    out[i] = ' '
                i += 1
            continue
        if src.startswith('/*', i):
            in_block = True
            out[i] = out[i + 1] = ' '
            i += 2
            continue
        if src.startswith('//', i):
            while i < n and src[i] != '\n':
                out[i] = ' '
                i += 1
            continue
        i += 1
    return ''.join(out)


def main(argv=None):
    ap = argparse.ArgumentParser(description='剥注释后扫描开发者口吻（只读）')
    ap.add_argument('--roots', nargs='+', default=DEFAULT_ROOTS,
                    help='要扫描的目录，默认 pages 与 components')
    ap.add_argument('--include-placeholders', action='store_true',
                    help='把批2 宽口径的四个占位词也纳入扫描（合法占位会命中，仅用于排查，不是归零判据）')
    ap.add_argument('--extra-pattern', default='',
                    help='追加到判据词表的正则片段')
    ap.add_argument('--check-detail-fallback', action='store_true',
                    help='检查 ReaderSettingsPage 里 openDetailSheet 的 title 是否都在 if(title===…) 或专用分支里被接住')
    args = ap.parse_args(argv)

    pattern = DEFAULT_PATTERN
    if args.include_placeholders:
        pattern += '|' + PLACEHOLDER_PATTERN
    if args.extra_pattern:
        pattern += '|' + args.extra_pattern
    pat = re.compile(pattern)

    hits = 0
    for root in args.roots:
        base = pathlib.Path(root)
        if not base.exists():
            continue
        for path in sorted(base.rglob('*.ets')):
            text = io.open(path, encoding='utf-8', errors='ignore').read()
            for lineno, line in enumerate(strip_comments(text).split('\n'), 1):
                if pat.search(line) and 'onUnavailableAction' not in line:
                    print('%s:%d: %s' % (path.as_posix(), lineno, line.strip()))
                    hits += 1

    if args.check_detail_fallback:
        # 批 4.7：把所有 openDetailSheet('X') 的 X 与 title==='X' / detailSheetTitle==='X'
        # 的分支比对，差集就是会掉进「尚未迁移」兜底句的落空项。
        rp = pathlib.Path('entry/src/main/ets/pages/ReaderSettingsPage.ets')
        if rp.exists():
            src = rp.read_text(encoding='utf-8')
            opened = set(re.findall(r"openDetailSheet\(\s*'([^']+)'", src))
            for m in re.finditer(r"openDetailSheet\(\s*this\.infoSubTab === 0 \? '([^']+)' : '([^']+)'", src):
                opened.add(m.group(1)); opened.add(m.group(2))
            matched = set(re.findall(r"(?:title|detailSheetTitle)\s*===\s*'([^']+)'", src))
            missing = sorted(opened - matched)
            if missing:
                print('落空 title（打开但无分支）：' + ', '.join(missing))
                hits += len(missing)
            else:
                print('落空 title 检查：0（%d 个 title 全部命中分支）' % len(opened))

    print('总命中 %d 行' % hits)
    return 0 if hits == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
