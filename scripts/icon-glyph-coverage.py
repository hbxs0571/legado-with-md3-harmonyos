#!/usr/bin/env python3
# 核对 AppGlyph 联合类型成员与 this.name === 分支是否一一对应。
# 用法：python scripts/icon-glyph-coverage.py [--repo <仓库根>]
# 退出码：0 = 一一对应；1 = 有成员缺分支或有分支不在类型里；2 = 找不到文件。
import argparse
import os
import re
import sys

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--repo', default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    args = ap.parse_args()
    p = os.path.join(args.repo, 'entry', 'src', 'main', 'ets', 'components', 'AppGlyph.ets')
    if not os.path.isfile(p):
        print('找不到 ' + p, file=sys.stderr)
        return 2
    s = open(p, encoding='utf-8').read()
    m = re.search(r'export type AppGlyphName\s*=([^;]+);', s)
    if not m:
        print('没解析到 AppGlyphName 类型', file=sys.stderr)
        return 2
    members = set(re.findall(r"'([A-Za-z_][A-Za-z0-9_]*)'", m.group(1)))
    branches = set(re.findall(r"this\.name === '([A-Za-z_][A-Za-z0-9_]*)'", s))
    missing = sorted(members - branches)
    extra = sorted(branches - members)
    print('成员 %d，分支 %d，缺分支 %d，多余分支 %d，有 else 兜底 %s' % (
        len(members), len(branches), len(missing), len(extra), s.count('} else {')))
    for n in missing:
        print('  缺分支: ' + n)
    for n in extra:
        print('  多余分支: ' + n)
    return 1 if (missing or extra) else 0

if __name__ == '__main__':
    sys.exit(main())
