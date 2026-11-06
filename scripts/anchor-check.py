#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
anchor-check.py —— 交接件的「文件:行」锚点体检（只读，绝不改仓库）

用法：
  # 1) 交接时：把当前真实内容抓成指纹基线
  python scripts/anchor-check.py capture tmp/cover-evidence.md -o tmp/cover-evidence.anchors.json

  # 2) 开工前/压缩前：比对基线，只打印失效清单
  python scripts/anchor-check.py check tmp/cover-evidence.anchors.json
  python scripts/anchor-check.py check tmp/cover-evidence.md -o tmp/x.rpt.txt   # 无基线时只验存在性

  # 3) 刷新基线（确认当前代码就是新的真相）
  python scripts/anchor-check.py refresh tmp/cover-evidence.anchors.json

退出码：0 = 全部锚点仍有效；1 = 有 STALE/MISSING；2 = 参数或读写错误。

为什么要有它：证据包、实现提示词、七张表全部建立在「文件:行」+ 某个 git HEAD 上，
而这个仓库同时有多个会话在改同一批文件。行号一漂，实现段拿着旧行号去 edit 就报
NOTFOUND，然后重读全文、再触发一轮压缩。本脚本把「行号是否还指着同一段代码」
变成可机器校验的事。
"""

import argparse
import json
import os
import re
import sys

# ---------------------------------------------------------------- 仓库根
#
# 本地仓库 = 本脚本所在仓库（scripts/ 的上一级），不写死绝对路径。
# 上游根 / 样本备份默认按同级目录推断，可用环境变量覆盖：
#   LEGADO_UPSTREAM   上游仓库根（含 app/src/main/java 的那一级）
#   LEGADO_SAMPLES    样本备份根（config.xml、backup2026-* 所在目录）

LOCAL_REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_PARENT = os.path.dirname(LOCAL_REPO)
UPSTREAM_REPO = os.environ.get("LEGADO_UPSTREAM") or os.path.join(_PARENT, "legado-with-MD3")
EXTRA_ROOTS = [os.environ.get("LEGADO_SAMPLES") or os.path.join(_PARENT, "测试")]
# 交接件目录（tmp/）：证据包之间会互相引用（如 layer2-evidence-package 指 layer2-impl-prompt.md）
# 默认取仓库同级的 tmp/，可用 LEGADO_HANDOFF_DIR 覆盖
TMP_DIR = os.environ.get("LEGADO_HANDOFF_DIR") or os.path.join(_PARENT, "tmp")

# 建文件名索引时扫这些子树（够用且快）
LOCAL_SCAN = ["entry/src/main/ets", "docs", "scripts", "AppScope"]
UPSTREAM_SCAN = ["app/src/main/java", "app/src/main/res", "app/src/main/assets"]

# 引用形如  xxx.ets:123  或 xxx.ets:123-456  或 xxx.ets:123:45
REF_RE = re.compile(
    r"(?P<path>[A-Za-z0-9_][A-Za-z0-9_./\\-]*\.(?:ets|ts|kt|java|json|json5|xml|md|sh|py|svg|txt|jsonl))"
    r":(?P<start>\d+)(?:-(?P<end>\d+))?"
)

# 占位 & 明显不是文件行的东西
BAD_START = {"0"}

_index_cache = None
_suffix_cache = None


def norm(s: str) -> str:
    """把一行压成单空格形式，避免缩进/空格差异造成假失效。"""
    return " ".join(s.split())


def build_suffix_index():
    """相对路径列表，供后缀匹配（`model/BookCover.kt` -> app/.../model/BookCover.kt）。"""
    global _suffix_cache
    if _suffix_cache is not None:
        return _suffix_cache
    rows = []
    for root, subs in ((LOCAL_REPO, LOCAL_SCAN), (UPSTREAM_REPO, UPSTREAM_SCAN)):
        for sub in subs:
            base = os.path.join(root, sub.replace("/", os.sep))
            if not os.path.isdir(base):
                continue
            for dirpath, _dirnames, filenames in os.walk(base):
                for fn in filenames:
                    full = os.path.join(dirpath, fn)
                    rel = os.path.relpath(full, root).replace(os.sep, "/")
                    rows.append((root, rel))
    _suffix_cache = rows
    return rows


def build_index():
    """basename -> [相对路径...]，用来解析只写文件名的引用（如 ReaderPage.ets:3631）。"""
    global _index_cache
    if _index_cache is not None:
        return _index_cache
    idx = {}
    for root, subs in ((LOCAL_REPO, LOCAL_SCAN), (UPSTREAM_REPO, UPSTREAM_SCAN)):
        for sub in subs:
            base = os.path.join(root, sub.replace("/", os.sep))
            if not os.path.isdir(base):
                continue
            for dirpath, _dirnames, filenames in os.walk(base):
                for fn in filenames:
                    full = os.path.join(dirpath, fn)
                    rel = os.path.relpath(full, root).replace(os.sep, "/")
                    idx.setdefault(fn, []).append((root, rel))
    # 仓库外样本（N:\HarmonyProjects\测试\...）：只索引顶层，避免把整书库扫进来
    for extra in EXTRA_ROOTS:
        try:
            for fn in os.listdir(extra):
                full = os.path.join(extra, fn)
                if os.path.isfile(full):
                    idx.setdefault(fn, []).append(("<abs>", full))
        except OSError:
            pass
    _index_cache = idx
    return idx


# 缩写表两种写法：
#   表格  | `简称` | `N:\...\文件.kt` |
#   列表  - `简称` = `app/src/main/java/...`（26 行）
ABBR_TABLE_RE = re.compile(r"^\|\s*`([^`|]+)`\s*\|\s*`([^`|]+)`\s*\|")
ABBR_LINE_RE = re.compile(r"^-\s*`([^`]+)`\s*=\s*`([^`]+)`")
ABBR_PREFIX_RE = re.compile(r"^.*前缀\s*`([^`]+)`\s*：?\s*$")


def parse_abbr(md_path: str):
    """
    解析缩写表，返回 name -> 绝对或相对路径。
    块内「前缀」声明加上 `…\\xxx.ets` 也能拼出完整路径。
    """
    abbr = {}
    prefix = None
    try:
        with open(md_path, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                s = line.rstrip("\n")
                m = ABBR_PREFIX_RE.match(s.strip())
                if m:
                    prefix = m.group(1).replace("\\", "/")
                    continue
                m = ABBR_TABLE_RE.match(s.strip())
                if not m and s.strip().startswith("- `"):
                    m = ABBR_LINE_RE.match(s.strip())
                if m:
                    name = m.group(1).strip()
                    target = m.group(2).strip().replace("\\", "/")
                else:
                    # 「- 样本 `config.xml` = `N:\...\config.xml`（381 行）」这类：名字不在行首反引号里，
                    # 就把行内那个反引号包裹的绝对路径按文件名登记
                    mm = re.search(r"^-\s*.{0,12}`([^`]+)`\s*=\s*`([A-Za-z]:[^`]+)`", s.strip())
                    if not mm:
                        continue
                    target = mm.group(2).strip().replace("\\", "/")
                    name = mm.group(1).strip() or os.path.basename(target)
                # 括号里的「（26 行）」之类已经被正则排除在外
                target = re.sub(r"\s*（[^）]*）\s*$", "", target)
                if target.startswith("…/"):
                    if not prefix:
                        continue
                    target = prefix.rstrip("/") + "/" + target[2:]
                abbr[name] = target
    except OSError:
        pass
    return abbr


ABS_PATH_RE = re.compile(r"[A-Za-z]:[\\/][^\s`'\"（）()|,，、；;]+")


def scan_abs_paths(md_path: str):
    """扫全文出现的绝对路径，按文件名登记（备份样本等仓库外材料靠这个兜底）。"""
    found = {}
    try:
        with open(md_path, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                for m in ABS_PATH_RE.finditer(line):
                    raw = m.group(0).rstrip("。，、；：")
                    p = raw.replace("\\", "/")
                    if not os.path.isfile(p):
                        continue
                    found.setdefault(os.path.basename(p), p)
    except OSError:
        pass
    return found


_abbr_cache = None
_self_md = None


def load_abbr(md_path: str):
    """在当前进程里启用某份交接件的缩写表，并记下它自身（供自引用解析）。"""
    global _abbr_cache, _self_md
    _abbr_cache = parse_abbr(md_path)
    # 缩写表没登记、但全文出现过绝对路径的文件（如 `- 备份样本：`N:\...\config.xml``）
    for name, p in scan_abs_paths(md_path).items():
        _abbr_cache.setdefault(name, p)
    _self_md = os.path.abspath(md_path)


def resolve(ref_path: str):
    """
    返回 (root, relpath) 或 None。
    优先级：缩写表 -> 仓库前缀直连 -> 后缀匹配（唯一命中）-> 文件名索引（唯一命中）。
    """
    global _abbr_cache
    p = ref_path.replace("\\", "/")
    while p.startswith("./"):
        p = p[2:]

    # 自引用（证据包用 `本文件名:行` 反向指自己某一节）：直接落到自身
    if _self_md and os.path.basename(p) == os.path.basename(_self_md):
        return ("<abs>", _self_md)
    # 形如 "HarmonyProjects/legado-with-MD3/app/..." —— 正则把盘符前的 "N:" 吃掉了
    for pre in ("HarmonyProjects/legado-with-MD3/", "HarmonyProjects/legado-with-md3-harmonyos/"):
        if p.startswith(pre):
            p = p[len(pre):]
            break
    if p.startswith("HarmonyProjects/"):
        # 可能是 tmp/ 下交接件之间的互相引用
        cand = os.path.join(TMP_DIR, p.split("tmp/", 1)[-1].replace("/", os.sep))
        return ("<abs>", cand) if os.path.isfile(cand) else None

    # 缩写表优先：交接件里「简称:行」就是靠它落到绝对路径的
    if _abbr_cache and p in _abbr_cache:
        target = _abbr_cache[p].replace("\\", "/")
        stripped = False
        for pre in ("N:/HarmonyProjects/legado-with-MD3/", "N:/HarmonyProjects/legado-with-md3-harmonyos/"):
            if target.startswith(pre):
                p = target[len(pre):]
                stripped = True
                break
        if not stripped:
            if re.match(r"^[A-Za-z]:/", target):
                # 落在仓库外（如样本备份）：直接按绝对路径读
                return ("<abs>", target) if os.path.isfile(target) else None
            # 缩写表里给的是仓库相对路径（app/... 或 entry/...），原样交给下面按前缀解析
            p = target

    if p.startswith("entry/") or p.startswith("docs/") or p.startswith("scripts/") or p.startswith("AppScope/"):
        cand = os.path.join(LOCAL_REPO, p.replace("/", os.sep))
        if os.path.isfile(cand):
            return (LOCAL_REPO, p)
        # 直连失败：往下走通用兜底（路径写错一层、或少了 pages/ 之类）
    elif p.startswith("app/"):
        cand = os.path.join(UPSTREAM_REPO, p.replace("/", os.sep))
        return (UPSTREAM_REPO, p) if os.path.isfile(cand) else None
    if "/" in p:
        for root in (LOCAL_REPO, UPSTREAM_REPO):
            cand = os.path.join(root, p.replace("/", os.sep))
            if os.path.isfile(cand):
                return (root, p)
        # entry/src/main/ets 前缀写漏了：补上再试
        for extra in ("entry/src/main/ets/", "entry/src/main/ets/pages/",
                      "entry/src/main/ets/data/", "entry/src/main/ets/components/",
                      "entry/src/main/resources/"):
            cand = os.path.join(LOCAL_REPO, (extra + p).replace("/", os.sep))
            if os.path.isfile(cand):
                return (LOCAL_REPO, extra + p)
        # 交接件之间互相引用（tmp/ 下另一份 md）
        cand = os.path.join(TMP_DIR, p.split("tmp/", 1)[-1].replace("/", os.sep))
        if os.path.isfile(cand):
            return ("<abs>", cand)
        # 样本备份等仓库外材料（N:\HarmonyProjects\测试\...）
        for extra in EXTRA_ROOTS:
            cand = os.path.join(extra, p.replace("/", os.sep))
            if os.path.isfile(cand):
                return ("<abs>", cand)
        # 后缀匹配：引用只给了路径尾部
        want = "/" + p
        hits = [(root, rel) for root, rel in build_suffix_index() if ("/" + rel).endswith(want)]
        if hits:
            hits.sort(key=lambda x: len(x[1]))
            return hits[0]
        # 后缀也没中：按文件名兜底（如 entry/src/main/ets/Index.ets 实际在 pages/Index.ets）
        fname = os.path.basename(p)
        return resolve(fname)
    hits = build_index().get(p) or []
    if len(hits) == 1:
        return hits[0]
    if len(hits) > 1:
        # 同名多处：源码树优先于仓库外样本，其次取路径最短的
        repo_hits = [h for h in hits if h[0] != "<abs>"]
        pool = repo_hits or hits
        pool.sort(key=lambda x: len(x[1]))
        return pool[0]
    return None  # 找不到


def read_lines(root: str, rel: str):
    # root == "<abs>" 时 rel 本身就是绝对路径（样本备份等在仓库外）
    if root == "<abs>":
        full = rel
    else:
        full = os.path.join(root, rel.replace("/", os.sep))
    try:
        with open(full, "r", encoding="utf-8", errors="replace") as f:
            return f.read().split("\n")
    except OSError:
        return None


def extract_refs(md_path: str):
    """从 markdown 里抽出全部「文件:行」引用，按出现顺序去重。"""
    out = []
    seen = set()
    with open(md_path, "r", encoding="utf-8", errors="replace") as f:
        for lineno, line in enumerate(f, 1):
            for m in REF_RE.finditer(line):
                raw = m.group(0)
                if raw in seen:
                    continue
                seen.add(raw)
                out.append({
                    "ref": raw,
                    "src_line": lineno,
                    "path": m.group("path"),
                    "start": int(m.group("start")),
                    "end": int(m.group("end")) if m.group("end") else None,
                    "ctx": norm(line)[:160],
                })
    return out


# ---------------------------------------------------------------- capture


def cmd_capture(args):
    load_abbr(args.md)
    refs = extract_refs(args.md)
    anchors = []
    missing, ambiguous = [], []
    for r in refs:
        if r["start"] == 0:
            continue
        res = resolve(r["path"])
        if res is None:
            hits = build_index().get(os.path.basename(r["path"].replace("\\", "/"))) or []
            (ambiguous if len(hits) > 1 else missing).append(r)
            continue
        root, rel = res
        lines = read_lines(root, rel)
        if lines is None:
            missing.append(r)
            continue
        start = r["start"]
        if start > len(lines):
            missing.append(r)
            continue
        anchors.append({
            "ref": r["ref"],
            "src_line": r["src_line"],
            "root": root,
            "file": rel,
            "line": start,
            "end": r["end"],
            "lines_total": len(lines),
            "text": norm(lines[start - 1]),
        })

    payload = {
        "source": os.path.abspath(args.md),
        "captured_at": _now(),
        "window": args.window,
        "anchors": anchors,
    }
    with open(args.out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(payload, f, ensure_ascii=False, indent=1)

    print(f"capture: 引用 {len(refs)} 条 -> 锚点 {len(anchors)} 条已抓指纹 -> {args.out}")
    if ambiguous:
        print(f"  歧义未抓 {len(ambiguous)} 条（同名文件多处命中，请写全路径）：")
        for r in ambiguous[:10]:
            print(f"    - {r['ref']}  (出处 src:{r['src_line']})")
    if missing:
        print(f"  解析失败/越界 {len(missing)} 条：")
        for r in missing[:10]:
            print(f"    - {r['ref']}  (出处 src:{r['src_line']})")
    return 0


# ---------------------------------------------------------------- check


def _locate(lines, text, anchor_line, window):
    """
    返回 (state, new_line)。
    state: OK / DRIFT（在窗口内漂移）/ MOVED（整文件里找到了新位置）/ STALE（找不到）
    """
    n = len(lines)
    if 1 <= anchor_line <= n and norm(lines[anchor_line - 1]) == text:
        return "OK", anchor_line
    lo = max(1, anchor_line - window)
    hi = min(n, anchor_line + window)
    for i in range(lo, hi + 1):
        if norm(lines[i - 1]) == text:
            return "DRIFT", i
    for i in range(1, n + 1):
        if norm(lines[i - 1]) == text:
            return "MOVED", i
    return "STALE", None


def _verify(anchors, window, verbose):
    ok = drift = moved = stale = gone = 0
    fails = []
    for a in anchors:
        root, rel = a["root"], a["file"]
        lines = read_lines(root, rel)
        if lines is None:
            gone += 1
            fails.append((a, "FILE-GONE", None))
            continue
        state, new_line = _locate(lines, a["text"], a["line"], window)
        if state == "OK":
            ok += 1
        elif state == "DRIFT":
            drift += 1
            fails.append((a, "DRIFT", new_line))
        elif state == "MOVED":
            moved += 1
            fails.append((a, "MOVED", new_line))
        else:
            stale += 1
            fails.append((a, "STALE", None))

    total = len(anchors)
    print(f"锚点 {total} 条：有效 {ok} / 窗口内漂移 {drift} / 跳到别处 {moved} / 内容已变 {stale} / 文件消失 {gone}")
    if verbose and ok:
        print("  （有效项未逐条列出）")
    if fails:
        print("")
        print("失效清单（只用这份，不要去读原始证据包）：")
        for a, kind, new_line in fails:
            tail = f" -> 现 {a['file']}:{new_line}" if new_line else ""
            print(f"  [{kind}] {a['ref']}{tail}")
            print(f"          原指纹: {a['text'][:100]}")
    return 1 if (stale or moved or gone) else 0


def cmd_check(args):
    if args.target.lower().endswith(".json"):
        with open(args.target, "r", encoding="utf-8") as f:
            payload = json.load(f)
        anchors = payload.get("anchors") or []
        window = args.window or payload.get("window") or 30
        print(f"check: 基线 {args.target}（来源 {payload.get('source', '?')}，抓取于 {payload.get('captured_at', '?')}）")
        rc = _verify(anchors, window, args.verbose)
    else:
        # 无基线：只做存在性 + 行号范围检查（抓不到指纹，抓不准漂移）
        load_abbr(args.target)
        refs = [r for r in extract_refs(args.target) if r["start"] > 0]
        missing, oob, good = [], [], 0
        for r in refs:
            res = resolve(r["path"])
            if res is None:
                missing.append(r)
                continue
            root, rel = res
            lines = read_lines(root, rel)
            if lines is None:
                missing.append(r)
                continue
            if r["start"] > len(lines) or (r["end"] and r["end"] > len(lines)):
                oob.append((r, len(lines)))
                continue
            good += 1
        print(f"check（无基线，仅验存在性）: 引用 {len(refs)} 条：在范围 {good} / 文件找不到 {len(missing)} / 行号越界 {len(oob)}")
        print("  提示：无基线只能发现「文件没了 / 行号超出文件长度」，发现不了内容漂移。")
        print("        交接时先跑一次 capture 生成基线，之后才对漂移有效。")
        for r in missing:
            print(f"  [MISSING] {r['ref']}  (出处 src:{r['src_line']})")
        for r, n in oob:
            print(f"  [OUT-OF-RANGE] {r['ref']}  文件只有 {n} 行  (出处 src:{r['src_line']})")
        rc = 0 if not (missing or oob) else 1

    if args.out:
        with open(args.out, "w", encoding="utf-8", newline="\n") as f:
            f.write(f"anchor-check report  {_now()}\n")
            f.write(f"target: {args.target}\n")
        print(f"（报告头已写入 {args.out}）")
    return rc


def cmd_refresh(args):
    """基线过期但内容是对的：把指纹按当前位置重抓一遍。"""
    with open(args.target, "r", encoding="utf-8") as f:
        payload = json.load(f)
    anchors = payload.get("anchors") or []
    window = payload.get("window") or 30
    changed = 0
    for a in anchors:
        lines = read_lines(a["root"], a["file"])
        if lines is None:
            continue
        state, new_line = _locate(lines, a["text"], a["line"], window)
        if state in ("DRIFT", "MOVED") and new_line:
            a["line"] = new_line
            a["text"] = norm(lines[new_line - 1])
            changed += 1
        elif state == "OK":
            a["text"] = norm(lines[a["line"] - 1])
    payload["captured_at"] = _now()
    with open(args.target, "w", encoding="utf-8", newline="\n") as f:
        json.dump(payload, f, ensure_ascii=False, indent=1)
    print(f"refresh: 重定位 {changed} 条锚点 -> {args.target}")
    return 0


def _now():
    import datetime
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="交接件「文件:行」锚点体检（只读仓库，只写 tmp/）",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="典型用法：\n"
               "  python scripts/anchor-check.py capture tmp/cover-evidence.md -o tmp/cover-evidence.anchors.json\n"
               "  python scripts/anchor-check.py check tmp/cover-evidence.anchors.json\n",
    )
    sub = ap.add_subparsers(dest="cmd", required=True)

    c = sub.add_parser("capture", help="抓当前内容作指纹基线")
    c.add_argument("md", help="证据包 / 提示词 markdown 路径")
    c.add_argument("-o", "--out", required=True, help="基线 JSON 输出路径（放 tmp/）")
    c.add_argument("-w", "--window", type=int, default=30, help="允许的漂移窗口（行），默认 30")
    c.set_defaults(func=cmd_capture)

    k = sub.add_parser("check", help="比对基线，只打印失效清单")
    k.add_argument("target", help="基线 JSON，或直接给 markdown（无基线模式）")
    k.add_argument("-w", "--window", type=int, default=0, help="覆盖基线里的窗口大小")
    k.add_argument("-o", "--out", help="报告头写入路径（可选）")
    k.add_argument("-v", "--verbose", action="store_true")
    k.set_defaults(func=cmd_check)

    r = sub.add_parser("refresh", help="把基线里能重定位的锚点按当前位置刷新")
    r.add_argument("target", help="基线 JSON")
    r.set_defaults(func=cmd_refresh)

    args = ap.parse_args(argv)
    try:
        return args.func(args)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
