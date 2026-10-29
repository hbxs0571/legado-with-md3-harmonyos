#!/usr/bin/env bash
# 输出某个 ZIP 类别的上游接触面清单（文件集 + 命中行号）。
# 只打印，不生成对照表，也不修改任何文件。
#
# 用法：
#   ./scripts/upstream-surface.sh <类别键名> [上游仓库根目录]
#   ./scripts/upstream-surface.sh bookmark ~/legado-with-MD3
#   ./scripts/upstream-surface.sh --list          # 列出全部类别与关键词
#
# 关键词来自 docs/parity/KEYWORDS.md，改那里即可，不用改本脚本。

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEYWORDS_FILE="$SCRIPT_DIR/../docs/parity/KEYWORDS.md"

die() { echo "错误：$*" >&2; exit 1; }

[ -f "$KEYWORDS_FILE" ] || die "找不到关键词表 $KEYWORDS_FILE"

# 从 KEYWORDS.md 的表格里提取「类别键名 -> 关键词」。
# 只认第一列被反引号包住、第二列也非空的行，跳过表头与分隔行。
# 表格里的 `\|` 是为避开 markdown 列分隔符而写的，这里还原成 ERE 的 `|`。
list_keywords() {
  grep -E '^\| *`[a-zA-Z]+` *\| *`[^`]+` *\|' "$KEYWORDS_FILE" \
    | sed -E 's/^\| *`([a-zA-Z]+)` *\| *`([^`]*)`.*/\1\t\2/' \
    | sed 's/\\|/|/g'
}

if [ "${1:-}" = "--list" ] || [ $# -eq 0 ]; then
  echo "类别键名            上游检索关键词"
  echo "-------------------- ----------------------------------------"
  list_keywords | awk -F '\t' '{ printf "%-20s %s\n", $1, $2 }'
  echo
  echo "共 $(list_keywords | wc -l | tr -d ' ') 个类别。"
  exit 0
fi

CATEGORY="$1"
REPO_ROOT="${2:-.}"
SRC_DIR="$REPO_ROOT/app/src/main/java"

KEYWORD="$(list_keywords | awk -F '\t' -v c="$CATEGORY" '$1 == c { print $2 }')"
if [ -z "$KEYWORD" ]; then
  echo "错误：关键词表里没有类别 $CATEGORY" >&2
  echo "可用类别：" >&2
  list_keywords | awk -F '\t' '{ print "  " $1 }' >&2
  exit 1
fi

[ -d "$SRC_DIR" ] || die "找不到上游源码目录 $SRC_DIR（第二个参数应为 Android 仓库根目录）"

TOTAL_KT=$(find "$SRC_DIR" -name '*.kt' -type f | wc -l | tr -d ' ')

echo "类别：$CATEGORY"
echo "关键词：$KEYWORD"
echo "上游源码：$SRC_DIR"
echo

# 分级：文件名命中 vs 仅内容命中。两者的差就是「只按文件名枚举会漏掉的部分」。
# 注意：对靠 config.xml 偏好键落地的类别（readConfig 等），类别键名与上游文件名本就不同名，
# 这项对比没有意义，因此只在文件名命中不超出内容命中时才报差额。
NAME_HITS=$(find "$SRC_DIR" -name '*.kt' -type f -iname "*${CATEGORY}*" 2>/dev/null | wc -l | tr -d ' ')
CONTENT_FILES=$(grep -rlE "$KEYWORD" "$SRC_DIR" --include='*.kt' 2>/dev/null)
CONTENT_HITS=$(printf '%s' "$CONTENT_FILES" | grep -c . )

echo "关键词命中文件：$CONTENT_HITS 个（上游 .kt 总数 $TOTAL_KT）"
if [ "$NAME_HITS" -le "$CONTENT_HITS" ] && [ "$NAME_HITS" -gt 0 ]; then
  echo "按类别键名当文件名去找：$NAME_HITS 个文件"
  echo "差额：$((CONTENT_HITS - NAME_HITS)) 个文件只能靠内容引用找到"
fi
echo

echo "=== 内容引用命中的文件（逐个确认引用方式，填进 docs/parity/STATUS.md 对应明细表）==="
printf '%s\n' "$CONTENT_FILES" | sed "s|^$SRC_DIR/||" | sort

echo
echo "=== 命中行（按文件分组，供定位上游位置 文件:行）==="
grep -rnE "$KEYWORD" "$SRC_DIR" --include='*.kt' 2>/dev/null \
  | sed "s|^$SRC_DIR/||" \
  | cut -c1-200

echo
echo "提示：以上只是盘点起点。逐文件确认引用方式后，把「上游能力 / 上游位置 / 本地位置 / 状态 / 差异 / 验收方式」写进"
echo "      docs/parity/ZIP-${CATEGORY^^}.md（先读 docs/parity/KEYWORDS.md 与 docs/CODE-CONVENTIONS.md 第四节）。"
