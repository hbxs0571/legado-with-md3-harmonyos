# -*- coding: utf-8 -*-
"""Markdown 交付物结构体检：一条命令过四项硬检 + 一项提示。

为什么有这个脚本：BOM / 换行符 / 围栏闭合 / 标题前空行 这四项每次交付 Markdown 都要过一遍，
历史上在 tmp/ 里被各写各的重写了 54 遍（那次盘点的证据见提交说明）。表格列数不在这里管 ——
那是 scripts/parity-pipes.py 的职责，两份脚本不要互相抄。

用法：
    python scripts/md-check.py tmp/x.md docs/Y.md
    python scripts/md-check.py docs          # 扫目录下的 *.md（默认不递归）
    python scripts/md-check.py docs -r       # 递归
    python scripts/md-check.py --repo /path/to/repo docs

退出码：0 = 无 FAIL（可能有 W 提示）；1 = 有 FAIL；2 = 参数或读写错误。

硬检（FAIL，退出码 1）：
  1) BOM：文件开头是 EF BB BF 即 FAIL。交付物一律 UTF-8 无 BOM。
  2) 换行符：只允许纯 LF 或纯 CRLF；混用或出现裸 CR 即 FAIL。
     不强制某一种，但同一文件必须统一（AGENTS.md：脚本整份重写必须沿用原换行符）。
  3) 围栏：三反引号计数必须偶数，且文件结束时不能仍在围栏内。
  4) 标题前空行：井号开头的行，上一行非空即 FAIL（围栏内不计）。

提示（W，不判 FAIL）：
  5) 围栏外孤立 @：@ 前后都不是单词字符 / 反引号 / 斜杠时会提示。
     不判 FAIL 是因为本仓库文档里 @ 也当分隔符用（例：`上游 @ 提交`、URL 里的 user@host），
     机器分不清「有意分隔」与「误写」，只能提醒人看一眼。
"""
import argparse
import os
import re
import sys

LF_CH = chr(10)
CR_CH = chr(13)
FENCE = chr(96) * 3
WORD = chr(92) + 'w'          # 正则里的元字符转义，避免源码里出现反斜杠
BOM_BYTES = bytes([0xEF, 0xBB, 0xBF])
HEADING = re.compile('^#{1,6} ')
# 前后都不是单词字符 / 反引号 / 斜杠 —— `@State`、a@b.com 都不算孤立
STRAY_AT = re.compile('(?<![' + WORD + chr(96) + '/])@(?![' + WORD + chr(96) + '])')


def reconfigure_stdout():
    """Windows 终端默认 GBK，中文报告会乱码；能改就改成 UTF-8。"""
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass


def check_eol(raw):
    """返回 (verdict, detail)，verdict 为 LF / CRLF / FAIL。"""
    cr = raw.count(CR_CH.encode())
    lf = raw.count(LF_CH.encode())
    crlf = raw.count((CR_CH + LF_CH).encode())
    bare_cr = cr - crlf
    if cr == 0:
        return 'LF', 'LF %d' % lf
    if bare_cr > 0:
        return 'FAIL', '出现裸 CR %d 处（CR %d / LF %d）' % (bare_cr, cr, lf)
    if crlf != lf:
        return 'FAIL', '换行符混用（CRLF %d / LF %d）' % (crlf, lf)
    return 'CRLF', 'CRLF %d' % crlf


def check_structure(text):
    """围栏闭合 / 标题前空行（FAIL）与孤立 @（W）。返回 (fails, warns, info)。"""
    lines = text.split(LF_CH)
    fails = []
    warns = []
    fences = 0
    in_fence = False
    headings = 0
    for idx, line in enumerate(lines, 1):
        stripped = line.rstrip(CR_CH)
        if stripped.startswith(FENCE):
            fences += 1
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        if HEADING.match(stripped):
            headings += 1
            prev = lines[idx - 2] if idx >= 2 else ''
            if idx >= 2 and prev.strip() != '':
                fails.append('标题前缺空行 line %d: %s' % (idx, stripped[:40]))
        if STRAY_AT.search(stripped):
            warns.append('孤立 @ line %d: %s' % (idx, stripped[:60]))
    if fences % 2 != 0:
        fails.append('围栏未闭合：三反引号共 %d 个（奇数）' % fences)
    elif in_fence:
        fails.append('围栏未闭合：文件结束时仍在围栏内')
    return fails, warns, 'fences %d / headings %d' % (fences, headings)


def check_file(path, quiet=False):
    """返回 (fail 数, warn 数)。"""
    with open(path, 'rb') as f:
        raw = f.read()
    fails = []
    if raw[:3] == BOM_BYTES:
        fails.append('有 BOM（应 UTF-8 无 BOM）')
    eol_verdict, eol_detail = check_eol(raw)
    if eol_verdict == 'FAIL':
        fails.append(eol_detail)
    try:
        text = raw.decode('utf-8-sig')
    except UnicodeDecodeError as exc:
        fails.append('不是合法 UTF-8：%s' % exc)
        text = raw.decode('utf-8', 'replace')
    struct_fails, warns, info = check_structure(text)
    fails.extend(struct_fails)
    if fails:
        print('FAIL %s' % path)
        for item in fails:
            print('     %s' % item)
        for item in warns:
            print('     W %s' % item)
        return 1, len(warns)
    if not quiet:
        print('OK   %s  [%s / %s]%s' % (path, eol_verdict, info, '' if not warns else '  W %d' % len(warns)))
    if warns and quiet:
        print('WARN %s' % path)
        for item in warns:
            print('     W %s' % item)
    return 0, len(warns)


def collect(paths, repo, recursive):
    out = []
    for p in paths:
        full = p if os.path.isabs(p) else os.path.join(repo, p)
        if os.path.isdir(full):
            if recursive:
                for root, _dirs, files in os.walk(full):
                    for name in sorted(files):
                        if name.endswith('.md'):
                            out.append(os.path.join(root, name))
            else:
                for name in sorted(os.listdir(full)):
                    fp = os.path.join(full, name)
                    if os.path.isfile(fp) and name.endswith('.md'):
                        out.append(fp)
        elif os.path.isfile(full):
            out.append(full)
        else:
            raise IOError('找不到：%s' % full)
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument('paths', nargs='+', help='文件或目录')
    ap.add_argument('--repo', default='.', help='相对路径的根，默认当前目录')
    ap.add_argument('-r', '--recursive', action='store_true', help='目录递归')
    ap.add_argument('-q', '--quiet', action='store_true', help='只打印失败与提示行')
    args = ap.parse_args(argv)
    reconfigure_stdout()
    try:
        files = collect(args.paths, args.repo, args.recursive)
    except IOError as exc:
        print(str(exc))
        return 2
    if not files:
        print('没有匹配的 .md 文件')
        return 2
    bad = 0
    nwarn = 0
    for fp in files:
        b, w = check_file(fp, quiet=args.quiet)
        bad += b
        nwarn += w
    print('---')
    print('%d 个文件，%d 个 FAIL，%d 条提示' % (len(files), bad, nwarn))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())