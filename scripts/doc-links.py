# -*- coding: utf-8 -*-
"""文档相对链接体检：找出 Markdown 里指向不存在文件的相对链接。

比原来的 tmp/linkchk.py 多做三件事：
1. 忽略代码块（``` 围栏内是示例，不是真链接）
2. 只认 .md 目标（图片链接与外部 http 链接不查）
3. 报告已剥离锚点（`foo.md#bar` 只查 foo.md 存不存在）

用法：
    python scripts/doc-links.py                    # 默认扫 docs/
    python scripts/doc-links.py docs README.md     # 扫多个目录/文件
    python scripts/doc-links.py --repo /path/to/repo docs

退出码：0 = 全部可解析；1 = 有断链。
"""
import argparse
import io
import os
import re
import sys

# [文字](目标) —— 目标不含 http/https，不含 #（纯锚点）
LINK_RE = re.compile(r'\[[^\]]*\]\(([^)\s#]+\.md)(#[^)]*)?\)')
FENCE_RE = re.compile(r'^\s*```')


def default_repo_root():
    here = os.path.dirname(os.path.abspath(__file__))
    guess = os.path.dirname(here)
    if os.path.isdir(os.path.join(guess, 'docs')):
        return guess
    return os.getcwd()


def strip_fences(text):
    """把 ``` 围栏内的行整段置空，但保持行数不变（报错行号才准）。"""
    out = []
    inside = False
    for line in text.split('\n'):
        if FENCE_RE.match(line):
            inside = not inside
            out.append('')
            continue
        out.append('' if inside else line)
    return '\n'.join(out)


def collect_md_files(root, targets):
    files = []
    for t in targets:
        p = t if os.path.isabs(t) else os.path.join(root, t)
        if os.path.isfile(p):
            files.append(p)
        elif os.path.isdir(p):
            for dirpath, _, names in os.walk(p):
                files.extend(os.path.join(dirpath, n) for n in names if n.endswith('.md'))
        else:
            print('既不是文件也不是目录：%s' % p, file=sys.stderr)
    return files


def main(argv=None):
    ap = argparse.ArgumentParser(description='文档相对链接体检')
    ap.add_argument('targets', nargs='*', default=None,
                    help='要扫的目录或文件（默认 docs/）')
    ap.add_argument('--repo', default=None, help='仓库根（默认按本文件位置推断）')
    args = ap.parse_args(argv)

    root = args.repo or default_repo_root()
    targets = args.targets or ['docs']
    files = collect_md_files(root, targets)
    if not files:
        print('没有找到任何 .md 文件', file=sys.stderr)
        return 2

    broken = []
    for path in files:
        text = strip_fences(io.open(path, encoding='utf-8').read())
        for m in LINK_RE.finditer(text):
            tgt = m.group(1)
            if re.match(r'^[a-zA-Z]+://', tgt):
                continue
            full = os.path.normpath(os.path.join(os.path.dirname(path), tgt))
            if not os.path.exists(full):
                broken.append((path, tgt))

    if broken:
        for path, tgt in broken:
            print('BROKEN %s -> %s' % (os.path.relpath(path, root).replace('\\', '/'), tgt))
        print('\n共 %d 处断链。归档或搬家后相对路径要跟着补 ../。' % len(broken))
        return 1

    print('OK 所有 md 链接可解析（扫了 %d 份）' % len(files))
    return 0


if __name__ == '__main__':
    sys.exit(main())
