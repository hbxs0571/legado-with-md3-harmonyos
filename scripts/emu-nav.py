#!/usr/bin/env python3
# 解析 uitest dumpLayout 的 JSON：把「控件身份 + 精确坐标」从树里取出来，
# 供 scripts/emu.sh 的 tree / tap / tap-text 使用。
# 用法与坑见 docs/EMULATOR.md 的「控件树取坐标」一节。
#
# 为什么要有它：截图目测坐标点不准（点色块要落进 56x56 才算命中），
# 而 dumpLayout 的节点带 bounds，是设备像素，取中心就精确。
# 图标按钮在树里可能没有 text/description（已验证），所以另给了 keys 子命令
# 打印实际存在的属性名，字段对不上时先用它校准，不要靠猜。
import json
import os
import sys

BOUNDS_KEYS = ('bounds', 'boundsRect', 'rect')
LABEL_KEYS = ('text', 'description', 'desc', 'content', 'hint', 'key', 'title')
CLICK_KEYS = ('clickable', 'enabled')


def die(msg, code=1):
    sys.stdout.flush()
    sys.stderr.write(msg + chr(10))
    raise SystemExit(code)


def load(path):
    if not os.path.isfile(path):
        die('找不到布局文件: %s' % path)
    try:
        with open(path, 'rb') as f:
            raw = f.read().decode('utf-8', 'replace')
    except OSError as e:
        die('读不了布局文件: %s' % e)
    start = raw.find('{')
    if start < 0:
        die('布局文件里没有 JSON 对象（hdc 输出可能为空或报错）')
    try:
        return json.loads(raw[start:])
    except ValueError as e:
        die('布局 JSON 解析失败: %s' % e)


def find_tree(root):
    """dumpLayout 的根可能是 {attributes, children}，也可能被包了一层。"""
    if isinstance(root, dict) and ('children' in root or 'attributes' in root):
        return root
    if isinstance(root, dict):
        for value in root.values():
            hit = find_tree(value) if isinstance(value, dict) else None
            if hit is not None:
                return hit
    return None


def parse_bounds(value):
    """支持 '[x1,y1][x2,y2]'、'x1,y1,x2,y2'、[x1,y1,x2,y2]、{left,top,right,bottom}。"""
    if value is None:
        return None
    if isinstance(value, dict):
        keys = ('left', 'top', 'right', 'bottom')
        if all(k in value for k in keys):
            try:
                return tuple(int(float(value[k])) for k in keys)
            except (TypeError, ValueError):
                return None
        return None
    if isinstance(value, (list, tuple)) and len(value) == 4:
        try:
            return tuple(int(float(v)) for v in value)
        except (TypeError, ValueError):
            return None
    if isinstance(value, str):
        digits = value
        for ch in '[](){}':
            digits = digits.replace(ch, ',')
        parts = [p.strip() for p in digits.split(',') if p.strip()]
        nums = []
        for p in parts:
            try:
                nums.append(int(float(p)))
            except ValueError:
                return None
        if len(nums) == 4:
            return tuple(nums)
    return None


def walk(root):
    """按前序展开，返回 [{depth, parent, attrs}]。"""
    out = []
    stack = [(root, -1, 0)]
    while stack:
        node, parent, depth = stack.pop()
        if not isinstance(node, dict):
            continue
        attrs = node.get('attributes')
        if not isinstance(attrs, dict):
            attrs = node if parent < 0 else {}
        idx = len(out)
        out.append({'depth': depth, 'parent': parent, 'attrs': attrs})
        kids = node.get('children')
        if isinstance(kids, list):
            for kid in reversed(kids):
                stack.append((kid, idx, depth + 1))
    return out


def first(attrs, keys):
    for k in keys:
        v = attrs.get(k)
        if isinstance(v, str) and v.strip():
            return v.strip()
        if isinstance(v, (int, float)):
            return str(v)
    return ''


def bounds_of(attrs):
    for k in BOUNDS_KEYS:
        box = parse_bounds(attrs.get(k))
        if box:
            return box
    return None


def is_clickable(attrs):
    v = attrs.get('clickable')
    if v is None:
        return False
    return str(v).strip().lower() == 'true'


def label_of(attrs):
    return first(attrs, LABEL_KEYS)


def type_of(attrs):
    return first(attrs, ('type', 'componentType', 'className', '@type'))


def nodes_with_boxes(root):
    nodes = walk(root)
    keep = []
    for i, n in enumerate(nodes):
        box = bounds_of(n['attrs'])
        if not box:
            continue
        n['idx'] = i
        n['box'] = box
        n['label'] = label_of(n['attrs'])
        n['type'] = type_of(n['attrs'])
        n['clickable'] = is_clickable(n['attrs'])
        keep.append(n)
    return keep


def center_of(box):
    l, t, r, b = box
    return ((l + r) // 2, (t + b) // 2)


def fmt_box(box):
    return '[%d,%d][%d,%d]' % box


def attr_keys(keep):
    seen = {}
    for n in keep:
        for k, v in n['attrs'].items():
            if k not in seen:
                seen[k] = str(v)[:40]
    return seen


def cmd_keys(path):
    root = find_tree(load(path))
    if root is None:
        die('没有找到控件树根节点')
    keep = nodes_with_boxes(root)
    print('节点 %d 个（带 bounds 的）' % len(keep))
    for k in sorted(attr_keys(keep)):
        print('  %-22s 示例: %s' % (k, attr_keys(keep)[k]))
    return 0


def cmd_list(path, show_all=False):
    root = find_tree(load(path))
    if root is None:
        die('没有找到控件树根节点')
    keep = nodes_with_boxes(root)
    rows = [n for n in keep if (show_all or n['clickable'] or n['label'])]
    if not rows:
        print('可点节点 0 个 —— 这个页面可能全用图片/自绘；先跑 emu.sh tree --keys 看实际字段')
        return 0
    print('可点/有字节点 %d 个（共 %d 个带 bounds 的节点）' % (len(rows), len(keep)))
    for i, n in enumerate(rows):
        print('%3d  %-14s %-24s %-26s %s' % (
            i,
            n['type'][:14] or '-',
            (n['label'] or '-')[:24],
            fmt_box(n['box']),
            'C' if n['clickable'] else '',
        ))
    return 0


def select(rows, text, contains, occurrence):
    if not text:
        return rows
    exact = [n for n in rows if n['label'] == text]
    pool = exact if exact else [n for n in rows if text in n['label']]
    if not pool and contains:
        pool = [n for n in rows if text.lower() in n['label'].lower()]
    return pool


def cmd_pick(path, index=None, text=None, contains=False, occurrence=0, show_all=False):
    root = find_tree(load(path))
    if root is None:
        die('没有找到控件树根节点')
    all_nodes = walk(root)
    keep = nodes_with_boxes(root)
    rows = [n for n in keep if (show_all or n['clickable'] or n['label'])]
    if index is not None:
        if index < 0 or index >= len(rows):
            die('序号 %d 超出范围（0..%d），先跑 emu.sh tree 看清单' % (index, len(rows) - 1), 3)
        target = rows[index]
    else:
        pool = select(rows, text, contains, occurrence)
        if not pool:
            die('没找到文字「%s」；先跑 emu.sh tree --all 看这一屏有哪些字' % text, 3)
        if len(pool) > 1 and occurrence == 0:
            print('命中 %d 个，未指定 --occurrence，拒绝猜：' % len(pool))
            for i, n in enumerate(pool):
                print('  [%d] %s %s %s' % (i, n['type'] or '-', n['label'][:30], fmt_box(n['box'])))
            die('请加 --occurrence N，或用 emu.sh tap <序号>', 4)
        target = pool[occurrence if occurrence < len(pool) else len(pool) - 1]
    node = target
    box = node['box']
    matched_label = node['label']
    if not node['clickable']:
        # 命中的多是内层 Text，可点的是外层容器：沿父链上溯找第一个可点且有 bounds 的祖先。
        cur = node['parent']
        seen = 0
        while cur is not None and cur >= 0 and seen < 20:
            cand = all_nodes[cur:cur + 1]
            if cand:
                attrs = cand[0]['attrs']
                cbox = bounds_of(attrs)
                if is_clickable(attrs) and cbox:
                    node = {'type': type_of(attrs), 'label': label_of(attrs), 'clickable': True, 'box': cbox}
                    box = cbox
                    break
                cur = cand[0]['parent']
            else:
                cur = None
            seen += 1
    cx, cy = center_of(box)
    print('目标: %s %s %s %s' % (node['type'] or '-', node['label'] or '-', fmt_box(box), 'C' if node['clickable'] else '非可点'))
    print('LABEL %s' % (matched_label or '',))
    print('CENTER %d %d' % (cx, cy))
    return 0


def label_multiset(root):
    keep = nodes_with_boxes(root) if root is not None else []
    items = {}
    for n in keep:
        if n['label']:
            items[n['label']] = items.get(n['label'], 0) + 1
    return items


def cmd_verify(pre_path, post_path, text=None):
    pre = label_multiset(find_tree(load(pre_path)))
    post = label_multiset(find_tree(load(post_path)))
    if text:
        exact_before, exact_after = pre.get(text, 0), post.get(text, 0)
        any_before = sum(v for k, v in pre.items() if text in k)
        any_after = sum(v for k, v in post.items() if text in k)
        print('目标「%s」: 精确 前 %d → 后 %d；含此文字 前 %d → 后 %d'
              % (text, exact_before, exact_after, any_before, any_after))
        if exact_before and not exact_after:
            print('判定: 精确命中已消失（页面变了，动作生效）')
        elif exact_before and exact_after:
            print('判定: 精确命中仍在（可能没点中，或这项本来就不随动作变化）')
        else:
            print('判定: 点击前就没精确命中，选择器可能没对上（改用 --contains）')
    added = [(k, post[k]) for k in post if k not in pre]
    if added:
        print('新出现的文字（前 8 条）:')
        for k, v in added[:8]:
            print('  + %s%s' % (k[:40], '' if v == 1 else ' x%d' % v))
    removed = [(k, pre[k]) for k in pre if k not in post]
    if removed:
        print('消失的文字（前 8 条）:')
        for k, v in removed[:8]:
            print('  - %s%s' % (k[:40], '' if v == 1 else ' x%d' % v))
    return 0


def main(argv):
    if len(argv) < 2:
        die('用法: emu-nav.py <keys|list|pick|verify> ...', 2)
    cmd = argv[1]
    args = argv[2:]
    index = text = None
    contains = False
    show_all = False
    occurrence = 0
    rest = []
    i = 0
    while i < len(args):
        a = args[i]
        if a == '--index':
            i += 1
            index = int(args[i])
        elif a == '--text':
            i += 1
            text = args[i]
        elif a == '--contains':
            contains = True
        elif a == '--all':
            show_all = True
        elif a == '--occurrence':
            i += 1
            occurrence = int(args[i])
        else:
            rest.append(a)
        i += 1
    if cmd == 'keys':
        return cmd_keys(rest[0])
    if cmd == 'list':
        return cmd_list(rest[0], show_all)
    if cmd == 'pick':
        return cmd_pick(rest[0], index, text, contains, occurrence, show_all)
    if cmd == 'verify':
        return cmd_verify(rest[0], rest[1], text)
    die('未知子命令: %s' % cmd, 2)


if __name__ == '__main__':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass
    sys.exit(main(sys.argv))