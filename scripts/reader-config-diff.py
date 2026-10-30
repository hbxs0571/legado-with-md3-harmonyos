#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""READER-CONFIG 字段差集复核脚本。

用途：复算「上游声明名 − 本地已落库字段」的字段级差集，
供 docs/parity/READER-CONFIG.md 第一节与第二节引用。

口径（与文档第一节一致，不可混算）：
  - 上游并集 = ReadBookConfig.kt 的 `data class Config(` 段 + 全文其余声明 + ReadSettings.kt 全部声明
  - 本地字段 = entry/src/main/ets/data/ReaderSettingsRepository.ets 里
    `ReaderSettingsSnapshot` 与 `ReaderInfoSettings` 两个接口的顶层字段
  - 差集逐项输出，不在这里套用「改名 / 容器 / 数组合并」的消账规则，
    消账规则写在文档里，脚本只负责给出原始名单与行号
"""

import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UP_BASE = os.environ.get(
    'UPSTREAM_ROOT', 'N:/HarmonyProjects/legado-with-MD3')
UP_SRC = os.path.join(UP_BASE, 'app/src/main/java/io/legado/app')
UP_CFG = os.path.join(UP_SRC, 'help/config/ReadBookConfig.kt')
UP_SET = os.path.join(UP_SRC, 'domain/model/settings/ReadSettings.kt')
LO_REPO = os.path.join(ROOT, 'entry/src/main/ets/data/ReaderSettingsRepository.ets')

DECL = re.compile(r'^\s+(?:(?:private|internal|public|override)\s+)?'
                  r'(?:val|var)\s+([A-Za-z_][A-Za-z0-9_]*)')


def parse_read_book_config(path):
    """返回 (Config 段内声明, 段外声明)，值是首次出现的行号。"""
    in_cfg = {}
    out_cfg = {}
    in_block = False
    end_line = 0
    for i, line in enumerate(io.open(path, encoding='utf-8').read().split('\n'), 1):
        if 'data class Config(' in line:
            in_block = True
            continue
        if in_block:
            # 结束行是 '    ) {'，正则漏写 \{ 会让边界识别失败
            if re.match(r'^    \)\s*\{?\s*$', line):
                in_block = False
                end_line = i
                continue
            m = DECL.match(line)
            if m and m.group(1) not in in_cfg:
                in_cfg[m.group(1)] = i
            continue
        if i <= end_line:
            continue
        m = DECL.match(line)
        if m and m.group(1) not in out_cfg:
            out_cfg[m.group(1)] = i
    return in_cfg, out_cfg


def parse_read_settings(path):
    """ReadSettings.kt 的 data class 构造函数声明。"""
    out = {}
    in_block = False
    for i, line in enumerate(io.open(path, encoding='utf-8').read().split('\n'), 1):
        if 'data class ReadSettings(' in line:
            in_block = True
            continue
        if in_block:
            if re.match(r'^\)', line):
                in_block = False
                continue
            m = DECL.match(line)
            if m and m.group(1) not in out:
                out[m.group(1)] = i
    return out


def parse_local(path):
    """本地接口字段。

    ReaderSettingsSnapshot 与 ReaderInfoSettings 都按两空格缩进的顶层字段解析；
    ReaderPaddingSettings 是容器，单独返回但不参与顶层比对。
    """
    text = io.open(path, encoding='utf-8').read().split('\n')
    result = {}
    current = None
    for i, line in enumerate(text, 1):
        m = re.match(r'^export interface (Reader[A-Za-z]*)', line)
        if m:
            current = m.group(1)
            result.setdefault(current, {})
            continue
        if re.match(r'^\}', line):
            current = None
            continue
        if current is None:
            continue
        m = re.match(r'^  ([A-Za-z][A-Za-z0-9]*)\??:', line)
        if m:
            result[current].setdefault(m.group(1), i)
    return result


def main():
    for p in (UP_CFG, UP_SET, LO_REPO):
        if not os.path.exists(p):
            sys.exit('缺少文件：%s' % p)

    cfg_in, cfg_out = parse_read_book_config(UP_CFG)
    settings = parse_read_settings(UP_SET)
    local = parse_local(LO_REPO)

    upstream = {}
    for src, tag in ((cfg_in, 'Config'), (cfg_out, 'Config外'), (settings, 'ReadSettings')):
        for name, line in src.items():
            if name not in upstream:
                upstream[name] = (tag, os.path.basename(
                    UP_CFG if tag != 'ReadSettings' else UP_SET), line)

    local_top = {}
    for iface in ('ReaderSettingsSnapshot', 'ReaderInfoSettings'):
        for name, line in local.get(iface, {}).items():
            local_top.setdefault(name, line)

    missing = sorted(n for n in upstream if n not in local_top)

    print('上游 Config 段内声明      : %d' % len(cfg_in))
    print('上游 Config 段外声明      : %d' % len(cfg_out))
    print('上游 ReadSettings 声明    : %d' % len(settings))
    print('上游合并去重              : %d' % len(upstream))
    print('本地顶层字段              : %d' % len(local_top))
    print('同名命中                  : %d' % (len(upstream) - len(missing)))
    print('原始差集（未消账）        : %d' % len(missing))
    print('')
    print('--- 原始差集逐项（上游名 / 出处 / 行号）---')
    for name in missing:
        tag, fname, line = upstream[name]
        print('%-32s %-12s %s:%d' % (name, tag, fname, line))


if __name__ == '__main__':
    main()
