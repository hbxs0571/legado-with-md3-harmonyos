#!/usr/bin/env bash
# 输出某个 ZIP 类别的上游接触面清单（文件集 + 命中行号）。
# 只打印，不生成对照表，也不修改任何文件。
#
# 用法：
#   ./scripts/upstream-surface.sh <类别键名> [上游仓库根目录]
#   ./scripts/upstream-surface.sh bookmark ~/legado-with-MD3
#   ./scripts/upstream-surface.sh --list          # 列出全部类别与关键词
#   ./scripts/upstream-surface.sh --coverage <类别> <表格路径> [上游仓库根目录]
#       生成覆盖证明清单：每个上游 .kt 是「已映射到某行」还是「未分配」。
#       未分配的文件必须补进表格，或显式写进「已排除」节并给出理由。
#
# 关键词来自 docs/parity/KEYWORDS.md，改那里即可，不用改本脚本。

set -u

# 界面白名单：个别界面文件既不提配置类名、也不提任何配置字段名，
# 只画已经算好的颜色和动画，关键词永远捞不到。这类文件逐个判断后按**精确文件名**纳入，
# 不做目录级 glob 兜底——整目录纳入会把同目录下与配置无关的实现一并拖进接触面，
# 多出的只是待解释条目，不是真缺口。
# 格式：每行 "相对 app/src/main/java 的目录|文件名1,文件名2|归属类别"。
# 第三段声明这条白名单是为哪个类别的关键词盲区加的（多个类别用逗号分隔，`*` 表示全部）。
# 不声明归属就会漏进别的类别的接触面：readConfig 的菜单渲染端若算进 localBook，
# 未分配清单里会出现一批与本类别无关的文件，覆盖证明就此失真。
# 新增白名单同时要写进 docs/parity/KEYWORDS.md 的「界面白名单」节，理由一并写在那里。
SURFACE_DIR_WHITELIST="
io/legado/app/ui/book/read|ReadBookMenuBarSearch.kt,SelectionMenuMotion.kt|readConfig
"

# 把界面白名单展开成文件清单，输出相对 app/src/main/java 的路径。
# 第二段是逗号分隔的精确文件名列表，逐个 stat 确认存在（不存在的名字要报出来，防止白名单烂在脚本里）。
# 传类别时只保留声明了该类别的白名单行；不传类别时全部纳入。
list_whitelist() {
  local category="${1:-}"
  printf '%s\n' "$SURFACE_DIR_WHITELIST" | while IFS='|' read -r dir pat cats; do
    [ -n "$dir" ] || continue
    [ -n "$pat" ] || continue
    if [ -n "$category" ]; then
      cats="${cats:-*}"
      if [ "$cats" != "*" ]; then
        case ",$cats," in
          *",$category,"*) ;;
          *) continue ;;
        esac
      fi
    fi
    printf '%s\n' "$pat" | tr ',' '\n' | while read -r name; do
      [ -n "$name" ] || continue
      if [ -f "$SRC_DIR/$dir/$name" ]; then
        printf '%s\n' "$dir/$name"
      else
        echo "警告：白名单文件不存在 $dir/$name" >&2
      fi
    done
  done
}

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

# 覆盖证明模式：--coverage <类别> <表格路径> [上游仓库根目录]
# 判据：上游接触面里每个 .kt，其基名（去掉 .kt）必须在表格文件中出现过。
# 出现在映射行里 = 已映射；出现在「已排除」节里 = 已排除并给了理由。
# 两者都没有 = 未分配，盘点不算完成。
if [ "${1:-}" = "--coverage" ]; then
  CATEGORY="${2:-}"
  TABLE="${3:-}"
  REPO_ROOT="${4:-.}"
  SRC_DIR="$REPO_ROOT/app/src/main/java"

  [ -n "$CATEGORY" ] || die "用法：--coverage <类别键名> <表格路径> [上游仓库根目录]"
  [ -n "$TABLE" ] || die "用法：--coverage <类别键名> <表格路径> [上游仓库根目录]"
  [ -f "$TABLE" ] || die "找不到表格文件 $TABLE"
  [ -d "$SRC_DIR" ] || die "找不到上游源码目录 $SRC_DIR"

  KEYWORD="$(list_keywords | awk -F '\t' -v c="$CATEGORY" '$1 == c { print $2 }')"
  [ -n "$KEYWORD" ] || die "关键词表里没有类别 $CATEGORY"

  # 上游接触面：按内容引用划定，再并上本类别声明了的界面白名单
  SURFACE=$({
    grep -rlE "$KEYWORD" "$SRC_DIR" --include='*.kt' 2>/dev/null | sed "s|^$SRC_DIR/||"
    list_whitelist "$CATEGORY"
  } | sort -u)
  TOTAL=$(printf '%s\n' "$SURFACE" | grep -c . )
  WL_COUNT=$(list_whitelist "$CATEGORY" | grep -c . )

  MAPPED=0
  UNASSIGNED=0
  UNASSIGNED_LIST=""

  while IFS= read -r f; do
    [ -n "$f" ] || continue
    base=$(basename "$f" .kt)
    if grep -qF "$base" "$TABLE"; then
      MAPPED=$((MAPPED + 1))
    else
      UNASSIGNED=$((UNASSIGNED + 1))
      UNASSIGNED_LIST="$UNASSIGNED_LIST$f"$'\n'
    fi
  done <<EOF
$SURFACE
EOF

  echo "类别：$CATEGORY"
  echo "关键词：$KEYWORD"
  echo "表格：$TABLE"
  echo "上游接触面：$TOTAL 个 .kt 文件（其中界面白名单 $WL_COUNT 个）"
  echo
  echo "已分配（基名在表格中出现）：$MAPPED"
  echo "未分配：$UNASSIGNED"
  echo

  if [ "$UNASSIGNED" -gt 0 ]; then
    echo "=== 未分配清单（须补进映射行，或写进「已排除」节并给出理由）==="
    printf '%s' "$UNASSIGNED_LIST"
    echo
    echo "结论：覆盖证明未通过（$UNASSIGNED / $TOTAL 未分配）。"
    exit 1
  else
    echo "结论：覆盖证明通过（$MAPPED / $TOTAL 全部已分配）。"
    exit 0
  fi
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
# 与 --coverage 同口径：关键词命中 ∪ 本类别声明的界面白名单
CONTENT_FILES=$({
  grep -rlE "$KEYWORD" "$SRC_DIR" --include='*.kt' 2>/dev/null | sed "s|^$SRC_DIR/||"
  list_whitelist "$CATEGORY"
} | sort -u)
CONTENT_HITS=$(printf '%s\n' "$CONTENT_FILES" | grep -c . )

echo "关键词命中文件：$CONTENT_HITS 个（上游 .kt 总数 $TOTAL_KT，其中界面白名单 $(list_whitelist "$CATEGORY" | grep -c . ) 个）"
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
