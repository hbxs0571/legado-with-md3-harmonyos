#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
evidence_lint.py —— 交接件的机器闸门（只读，绝不改仓库）

把三段分工里那些「写在提示词里的自然语言纪律」变成可执行的检查。
取证段产出不通过 lint，就不该进判断段。

用法：
  python tmp/evidence_lint.py tmp/cover-evidence.md
  python tmp/evidence_lint.py --all            # 检查 tmp/ 下所有 *evidence*.md 与 *prompt*.md
  python tmp/evidence_lint.py --stage judge tmp/keyboardassists-judge-prompt.md

退出码：0 = 通过（可能有 warning）；1 = 有 error（不许进下一段）；2 = 参数/读写错误。

规则分两类：
  E = 一旦出现就 blocking（结构性缺陷）
  W = 提示（不拦，但要在证据包里说明）
"""

import argparse
import glob
import os
import re
import sys

# ---------------------------------------------------------------- 规则定义

# 判断词：取证段只出材料，不下结论。这些词出现在证据包里一律算 error。
JUDGE_WORDS = [
    "已完成", "已对齐", "已实现", "已验证", "已通过",
    "基本完成", "部分接入", "部分接", "待定",
    "应该", "大概", "可能", "估计", "我觉得", "推测",
    "建议改为", "建议这样", "建议改成",
]
# 判断词的过滤只在取证段做；实现段里「应该」「可能」是正常用语，不算结论

# 状态三值：只许在判断段的产出里出现
STATUS_WORDS = ["已接", "未接", "不适用"]

# 头部必备项（regex, 人类可读名）
HEADER_REQUIRES = [
    (r"git\s+log|commit\s+[0-9a-f]{7,40}|HEAD\s+[0-9a-f]{7,40}", "开工状态：应有 git HEAD / commit 号"),
    (r"git\s+status|工作区|未提交", "开工状态：应有 git status 说明"),
    (r"未查到", "应声明「查不到写未查到」的口径"),
]

# 「文件:行」引用
REF_RE = re.compile(
    r"[A-Za-z0-9_][A-Za-z0-9_./\\-]*\.(?:ets|ts|kt|java|json|json5|xml|md|sh|py|svg|txt)"
    r":\d+"
)

# 每节至少要带几条引用（粗略判断「这一节是不是纯叙述」）
SECTION_RE = re.compile(r"^#{2,3}\s+(.+)$")


def read_text(path):
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        return f.read()


def strip_code_blocks(text):
    """
    去掉 ``` 围栏里的内容（那是示例命令/代码，不是结论）。
    返回 (去代码块后的行列表, 原始行列表)，两者行号对齐。
    """
    raw = text.split("\n")
    out = []
    in_fence = False
    for line in raw:
        s = line.strip()
        if s.startswith("```"):
            in_fence = not in_fence
            out.append("")
            continue
        out.append("" if in_fence else line)
    return out, raw


# 这些行说的是「工具跑通了」（覆盖证明、构建、脚本），不是「功能对齐了」→ 降级为 warn
TOOL_PASS_MARKERS = ("覆盖证明", "build-hap", "构建", "脚本", "检查通过", "链接可解析", "退出码 0")
PROHIBIT_MARKERS = (
    "不写", "不许", "禁止", "禁写", "不得", "别写", "不做", "不宣布", "零命中",
    "不要写", "别在", "不要宣布", "不许宣布", "不等于",
)


INLINE_CODE_RE = re.compile(r"`[^`\n]*`")
QUOTED_RE = re.compile(r"[「『][^」』\n]*[」』]")
COMMENT_LINE_RE = re.compile(r"^\s*(//|#|\*)")


def scrub(line: str) -> str:
    """
    去掉「提及区」，只留真正在说话的正文：
      - 行内代码 `...`（那是在引用代码/命令，不是在断言）
      - 「...」「『...』」引号里的内容（那是在举例某个词）
      - 行首注释
      - 表格里引用的上游源码片段（含 <br> 或 // 的表格行）
    """
    if COMMENT_LINE_RE.match(line):
        return ""
    if line.lstrip().startswith("|") and ("<br>" in line or "//" in line):
        return ""
    s = INLINE_CODE_RE.sub(" ", line)
    s = QUOTED_RE.sub(" ", s)
    return s


def is_constraint_mention(line: str, word: str) -> bool:
    """整行是禁止语/自查清单/标题时，不算把该词当结论用。"""
    s = line.strip()
    if s.startswith("#"):
        return True
    if any(m in s for m in PROHIBIT_MARKERS):
        return True
    # 词本身被禁止语紧邻修饰：「…不写『已完成』…」
    if re.search(r"(不写|禁止|不许|不得|别写|不宣布)[^。\n]{0,24}" + re.escape(word), s):
        return True
    return False


def detect_stage(path: str) -> str:
    name = os.path.basename(path).lower()
    if "evidence" in name:
        return "evidence"
    if "judge" in name:
        return "judge"
    return "impl"


def lint(path, stage="auto"):
    errors, warnings = [], []
    if stage == "auto":
        stage = detect_stage(path)
    text = read_text(path)
    plain, raw = strip_code_blocks(text)

    # ---------------- 1. 头部结构
    head = "\n".join(plain[:60])
    for rx, msg in HEADER_REQUIRES:
        if not re.search(rx, head):
            warnings.append(f"头部缺项：{msg}")

    # ---------------- 2. 禁用词（不含代码块）
    if stage == "evidence":
        for i, line in enumerate(plain, 1):
            core = scrub(line)
            if not core.strip():
                continue
            for w in JUDGE_WORDS:
                if w in core and not is_constraint_mention(line, w):
                    if w == "待定" and re.search(r"(状态|未接|不适用|三值)", line):
                        # 「状态只允许三值，不设待定」这类口径说明
                        warnings.append(f":{i} 「待定」出现在状态口径说明里 -> {line.strip()[:80]}")
                        continue
                    errors.append(f":{i} 取证段出现判断词「{w}」 -> {line.strip()[:90]}")
    else:
        # 判断/实现段允许出现状态词，但不许写「已完成 / 已对齐」这类自证
        for i, line in enumerate(plain, 1):
            core = scrub(line)
            if not core.strip():
                continue
            for w in ("已完成", "已对齐", "已验证", "已通过", "基本完成"):
                if w in core and not is_constraint_mention(line, w):
                    if any(m in line for m in TOOL_PASS_MARKERS):
                        warnings.append(f":{i} 「{w}」用在工具/证明上（非功能对齐），不算自证 -> {line.strip()[:80]}")
                        continue
                    errors.append(f":{i} 出现自证词「{w}」 -> {line.strip()[:90]}")

    # ---------------- 3. 「文件:行」密度
    refs = REF_RE.findall(text)
    body_lines = sum(1 for l in plain if l.strip())
    if refs:
        density = len(refs) / max(1, body_lines)
        if density < 0.02:
            warnings.append(f"引用密度偏低：{len(refs)} 条 / {body_lines} 行正文（{density:.3f}）")
    elif stage == "evidence":
        errors.append("全文没有任何「文件:行」引用——取证段的核心要求就是每条材料带行号")

    # ---------------- 4. 逐节检查：有实质内容的节应带引用
    cur_title, cur_start, cur_refs = None, 0, 0
    sections = []
    for i, line in enumerate(plain, 1):
        m = SECTION_RE.match(line)
        if m:
            if cur_title:
                sections.append((cur_title, cur_start, cur_refs))
            cur_title, cur_start, cur_refs = m.group(1).strip(), i, 0
        else:
            cur_refs += len(REF_RE.findall(line))
    if cur_title:
        sections.append((cur_title, cur_start, cur_refs))

    thin = [s for s in sections if s[2] == 0]
    # 目录/口径/结论类小节天然可以没有引用，只提示不拦
    ignore_kw = ("口径", "纪律", "禁用", "目录", "说明", "索引", "自查", "附录", "缩写表", "起点", "范围")
    real_thin = [s for s in thin if not any(k in s[0] for k in ignore_kw)]
    if real_thin and stage == "evidence":
        for title, start, _ in real_thin[:8]:
            warnings.append(f":{start} 小节「{title}」没有任何「文件:行」引用")

    # ---------------- 5. 自证/断言式句子
    for i, line in enumerate(plain, 1):
        s = line.strip()
        if not s or len(s) < 6:
            continue
        if re.search(r"(都对齐了|完全一致|没有问题|没问题|放心|绝对)", s):
            warnings.append(f":{i} 出现绝对化断言 -> {s[:80]}")

    # ---------------- 6. 必须声明「不动仓库」
    joined = "\n".join(plain)
    if stage == "evidence" and not re.search(r"(未改动|不修改|只读|不碰仓库|未 git|没有改)", joined):
        warnings.append("头部没有声明「仓库未被改动 / 只读」")

    return errors, warnings, len(refs), len(sections)


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="交接件 lint：把提示词里的纪律变成机器检查（只读）",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="退出码 0=通过 1=有 error（不许进下一段） 2=参数错误\n",
    )
    ap.add_argument("files", nargs="*", help="要检查的 markdown")
    ap.add_argument("--all", action="store_true", help="检查 tmp/ 下全部 *evidence*.md / *prompt*.md")
    ap.add_argument("--stage", choices=["auto", "evidence", "judge", "impl"], default="auto",
                    help="auto=按文件名推断（*evidence*=取证段禁用判断词；*judge*/*prompt*=允许状态词但禁自证）")
    ap.add_argument("--quiet", action="store_true", help="只打印汇总与 error")
    args = ap.parse_args(argv)

    files = list(args.files)
    if args.all:
        # 交接件目录默认是仓库同级的 tmp/（可用 LEGADO_HANDOFF_DIR 覆盖）
        repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        base = os.environ.get("LEGADO_HANDOFF_DIR") or os.path.join(os.path.dirname(repo), "tmp")
        if not os.path.isdir(base):
            print(f"--all 找不到交接件目录：{base}\n用 LEGADO_HANDOFF_DIR 指定，或直接给文件路径。", file=sys.stderr)
            return 2
        files += sorted(glob.glob(os.path.join(base, "*evidence*.md")))
        files += sorted(glob.glob(os.path.join(base, "*prompt*.md")))
        files = list(dict.fromkeys(files))
    if not files:
        print("没有要检查的文件。给路径，或用 --all。", file=sys.stderr)
        return 2

    total_err = 0
    for f in files:
        try:
            errors, warnings, nrefs, nsec = lint(f, args.stage)
        except OSError as exc:
            print(f"ERROR {f}: {exc}", file=sys.stderr)
            return 2
        name = os.path.basename(f)
        status = "FAIL" if errors else ("WARN" if warnings else "OK  ")
        print(f"[{status}] {name}  引用 {nrefs} 条 / 小节 {nsec} 个 / error {len(errors)} / warn {len(warnings)}")
        for e in errors:
            print(f"    E {e}")
        if not args.quiet:
            for w in warnings[:6]:
                print(f"    W {w}")
            if len(warnings) > 6:
                print(f"    W …还有 {len(warnings) - 6} 条")
        total_err += len(errors)

    print("")
    print(f"合计 {len(files)} 份文件，error {total_err} 条。")
    if total_err:
        print("有 error 的交接件不许进下一段——先修掉，或在证据包里显式说明为什么这条不适用。")
    return 1 if total_err else 0


if __name__ == "__main__":
    sys.exit(main())
