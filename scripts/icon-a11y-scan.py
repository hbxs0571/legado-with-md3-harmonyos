#!/usr/bin/env python3
# 扫 icon-only 可点控件与其无障碍文案覆盖情况。
# 用法：python scripts/icon-a11y-scan.py [--repo <仓库根>] [--json]
# 退出码：0 = 全部（或剩余未覆盖数为 0）；1 = 仍有未覆盖；2 = 参数/路径错误。
import argparse
import json
import os
import re
import sys

def find_container_start(lines, close_idx):
    #  从含右花括号的 close_idx 行向前走，累加 { } 直到归零
    depth = 0
    for k in range(close_idx, -1, -1):
        for ch in reversed(lines[k]):
            if ch == '}':
                depth += 1
            elif ch == '{':
                depth -= 1
                if depth == 0:
                    return k
    return -1

def skip_modifier_lines(lines, i):
    #  从 .onClick 行向前跳过纯修饰行与空行，找到容器闭合行
    k = i
    while k >= 0:
        st = lines[k].strip()
        if st.startswith('.') or len(st) == 0 or st.startswith(')'):
            k -= 1
            continue
        break
    return k

def scan_file(path):
    lines = open(path, encoding='utf-8', errors='replace').read().split(chr(10))
    out = []
    for i, line in enumerate(lines):
        if '.onClick(' not in line:
            continue
        k = skip_modifier_lines(lines, i)
        if k < 0:
            continue
        tail = lines[k].strip()
        if not (tail.endswith('}') or tail.endswith('})')):
            continue
        start = find_container_start(lines, k)
        if start < 0:
            continue
        body = chr(10).join(lines[start:k + 1])
        has_icon = ('app.media' in body) or ('AppGlyph(' in body)
        has_text = re.search(r'(?<![A-Za-z])Text\s*\(', body) is not None
        if (not has_icon) or has_text:
            continue
        chain = chr(10).join(lines[k + 1:i + 3])
        out.append({
            'line': i + 1,
            'a11y': 'accessibilityText' in chain,
            'snippet': line.strip()[:80],
        })
    return out

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--repo', default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    ap.add_argument('--json', action='store_true')
    args = ap.parse_args()
    root = os.path.join(args.repo, 'entry', 'src', 'main', 'ets')
    if not os.path.isdir(root):
        print('找不到目录：' + root, file=sys.stderr)
        return 2
    rows = []
    for d, _, fs in os.walk(root):
        for f in sorted(fs):
            if not f.endswith('.ets'):
                continue
            p = os.path.join(d, f)
            rel = os.path.relpath(p, root).replace(chr(92), '/')
            for r in scan_file(p):
                rows.append({'file': rel, 'line': r['line'], 'a11y': r['a11y'], 'snippet': r['snippet']})
    rows.sort(key=lambda r: (r['file'], r['line']))
    if args.json:
        print(json.dumps(rows, ensure_ascii=False, indent=1))
    else:
        for r in rows:
            flag = 'a11y' if r['a11y'] else 'MISS'
            print('%s  %s:%d  %s' % (flag, r['file'], r['line'], r['snippet']))
    total = len(rows)
    covered = sum(1 for r in rows if r['a11y'])
    print('# icon-only 可点控件 %d，其中有 accessibilityText %d，缺 %d' % (total, covered, total - covered))
    return 1 if covered < total else 0

if __name__ == '__main__':
    sys.exit(main())
