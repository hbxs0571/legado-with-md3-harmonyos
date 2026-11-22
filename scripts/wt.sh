#!/usr/bin/env bash
# worktree 管家：查出所有 git worktree 的脏/净、大小、闲置时长，并回收干净的。
#
# 用法：
#   bash scripts/wt.sh                 # = list，列出全部
#   bash scripts/wt.sh gc              # 删「干净 + 闲置超过 6 小时」的（默认不动脏的）
#   bash scripts/wt.sh gc --older 2    # 阈值改成 2 小时
#   bash scripts/wt.sh gc --dry-run    # 只列出会删哪些，不动手
#   bash scripts/wt.sh rm <名字或路径>  # 删指定的一个（有未提交改动的拒绝，脚本永不强删）
#
# 退出码：0 正常 / 1 参数错 / 2 有脏的拦下 / 3 找不到目标
#
# 为什么需要它：DSH 的 create_worktree 建的检出「checkout and branch remain」，
# 会话结束不会自动回收。2026-11-22 一天堆了 11 个、约 1.9 GB。

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
MAIN_ROOT=$(git -C "$SCRIPT_DIR/.." rev-parse --show-toplevel 2>/dev/null)
[ -n "$MAIN_ROOT" ] || { echo "不是 git 仓库：$SCRIPT_DIR/.." >&2; exit 1; }
PARENT=$(dirname "$MAIN_ROOT")

die() { echo "$*" >&2; exit 1; }

human() {
  awk -v n="${1:-0}" 'BEGIN{ if(n>=1024) printf "%.1fGB", n/1024; else printf "%dMB", n }'
}

collect() {
  # 每块：worktree <path> / HEAD <sha> / branch <ref>|detached / 空行
  local cur="" sha="" br="" line
  while IFS= read -r line; do
    case "$line" in
      'worktree '*) cur="${line#worktree }" ;;
      'HEAD '*) sha="${line#HEAD }" ;;
      'branch '*) br="${line#branch }" ;;
      'detached') br="(detached)" ;;
      '')
        [ -n "$cur" ] && printf '%s\t%s\t%s\n' "$cur" "$sha" "$br"
        cur=""; sha=""; br=""
        ;;
    esac
  done < <(git -C "$MAIN_ROOT" worktree list --porcelain)
  [ -n "$cur" ] && printf '%s\t%s\t%s\n' "$cur" "$sha" "$br"
  return 0
}

dir_mtime() { stat -c %Y "$1" 2>/dev/null || echo 0; }

do_list() {
  local total=0 dirty_n=0 p sha br n sz mt age tag
  while IFS=$'\t' read -r p sha br; do
    [ -n "$p" ] || continue
    if [ "$p" = "$MAIN_ROOT" ]; then
      printf '%-46s %-12s %6s %4s  %s\n' "(主仓) $(basename "$p")" 'main' '-' '-' '当前工作区'
      continue
    fi
    if [ ! -d "$p" ]; then
      printf '%-46s %s\n' "$(basename "$p")" '目录已不存在（注册残留，可 git worktree prune）'
      continue
    fi
    n=$(git -C "$p" status --short 2>/dev/null | wc -l | tr -d ' ')
    sz=$(du -sm "$p" 2>/dev/null | awk '{print $1}')
    mt=$(dir_mtime "$p")
    age=$(( $(date +%s) - mt ))
    if [ "$age" -lt 3600 ]; then age="$(( age / 60 )) 分钟前";
    elif [ "$age" -lt 86400 ]; then age="$(( age / 3600 )) 小时前";
    else age="$(( age / 86400 )) 天前"; fi
    total=$(( total + ${sz:-0} ))
    if [ "${n:-0}" -gt 0 ]; then dirty_n=$(( dirty_n + 1 )); tag='有改动，不可回收'; else tag='干净，可回收'; fi
    printf '%-46s %-12s %6s %4s  %-10s %s\n' "$(basename "$p")" "$br" "$(human "${sz:-0}")" "${n:-0}" "$age" "$tag"
  done < <(collect)
  echo ""
  echo "合计约 $(human "$total")；有改动的 $dirty_n 个（这些不能自动回收）"
}

do_gc() {
  local older=6 dry=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --older) [ $# -ge 2 ] || die '--older 需要数字'; older="$2"; shift 2 ;;
      --dry-run) dry=1; shift ;;
      *) die "未知参数：$1" ;;
    esac
  done
  local p sha br n mt age secs removed=0 keptdirty=0 keptyoung=0
  while IFS=$'\t' read -r p sha br; do
    [ -n "$p" ] || continue
    [ "$p" = "$MAIN_ROOT" ] && continue
    if [ ! -d "$p" ]; then
      echo "清注册残留：$(basename "$p")"
      git -C "$MAIN_ROOT" worktree prune >/dev/null 2>&1
      continue
    fi
    n=$(git -C "$p" status --short 2>/dev/null | wc -l | tr -d ' ')
    if [ "${n:-0}" -gt 0 ]; then
      keptdirty=$(( keptdirty + 1 ))
      echo "跳过（有 $n 个未提交改动）：$(basename "$p")"
      continue
    fi
    mt=$(dir_mtime "$p")
    secs=$(( $(date +%s) - mt ))
    if [ "$secs" -lt $(( older * 3600 )) ]; then
      keptyoung=$(( keptyoung + 1 ))
      echo "跳过（$(( secs / 60 )) 分钟前才动过，未满 ${older} 小时）：$(basename "$p")"
      continue
    fi
    if [ "$dry" -eq 1 ]; then
      echo "会删：$(basename "$p")"
      removed=$(( removed + 1 ))
    else
      if git -C "$MAIN_ROOT" worktree remove "$p" 2>/dev/null; then
        echo "已删：$(basename "$p")"
        removed=$(( removed + 1 ))
      else
        echo "删除失败（可能有文件被占用）：$(basename "$p")" >&2
      fi
    fi
  done < <(collect)
  echo ""
  echo "结果：$( [ "$dry" -eq 1 ] && echo 将删 || echo 已删 ) $removed；因有改动保留 $keptdirty；因未满 ${older} 小时保留 $keptyoung"
  [ "$keptdirty" -gt 0 ] && echo "提示：有改动的 worktree 请先确认那些改动要不要（git -C <路径> diff），再决定提交还是丢弃，脚本不会替你删。"
  return 0
}

do_rm() {
  local target="${1:-}"
  [ -n "$target" ] || die '用法：wt.sh rm <名字或完整路径>'
  local path="$target"
  if [ ! -d "$path" ]; then path="$PARENT/$target"; fi
  [ -d "$path" ] || die "找不到目录：$target"
  if [ "$path" = "$MAIN_ROOT" ]; then die '不能删主仓'; fi
  local n
  n=$(git -C "$path" status --short 2>/dev/null | wc -l | tr -d ' ')
  if [ "${n:-0}" -gt 0 ]; then
    echo "该 worktree 有 $n 个未提交改动，脚本不删：" >&2
    git -C "$path" status --short >&2
    echo "先确认这些改动要不要（git -C $path diff）：要就提交，不要就手动处理，之后本脚本才能删。" >&2
    exit 2
  fi
  git -C "$MAIN_ROOT" worktree remove "$path" && echo "已删除：$(basename "$path")"
}
case "${1:-list}" in
  list) shift || true; do_list ;;
  gc) shift || true; do_gc "$@" ;;
  rm) shift || true; do_rm "$@" ;;
  -h|--help) sed -n '3,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' ;;
  *) die "未知子命令：$1（可用 list / gc / rm）" ;;
esac
