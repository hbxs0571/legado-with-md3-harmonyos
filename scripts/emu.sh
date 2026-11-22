#!/usr/bin/env bash
# 模拟器启停、探活与截图。
# 说明见 docs/EMULATOR.md —— 这里只放最小实现，坑和理由都写在文档里。
set -o pipefail

DEVECO_ROOT="${DEVECO_STUDIO_HOME:-/d/Program Files/Huawei/DevEco Studio}"
EMU_BIN="$DEVECO_ROOT/tools/emulator/Emulator.exe"
HDC_BIN="$DEVECO_ROOT/sdk/default/openharmony/toolchains/hdc.exe"
AVD_NAME="${AVD_NAME:-Mate 90 Pro}"
TARGET="${TARGET:-127.0.0.1:5555}"
# 1280x2832 / 560dpi → 3.5。掉成 1.5 时视口变 853x1888vp，整屏 UI 偏小。
EXPECT_DENSITY="${EXPECT_DENSITY:-3.5}"
BOOT_TIMEOUT="${BOOT_TIMEOUT:-240}"

export MSYS_NO_PATHCONV=1

# 控件树解析脚本与本脚本同目录 —— 不要从别的目录调本脚本。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 本脚本跑在 Git Bash 下，但 python 是 Windows 版：交给 python 的路径必须是原生形式，
# 否则 /n/... 会被当成 N:\n\...（MSYS_NO_PATHCONV=1 关掉了自动转换，这里自己转）。
# python 的报错与 pickseq 输出都是中文，统一设成 UTF-8，免得在 GBK 终端下变成乱码。
export PYTHONIOENCODING=utf-8

to_native() {
  case "$1" in
    [A-Za-z]:*) printf '%s' "$1" ;;
    *) cygpath -w "$1" 2>/dev/null || printf '%s' "$1" ;;
  esac
}
NAV_PY="$(to_native "$SCRIPT_DIR/emu-nav.py")"
# dumpLayout 先写设备侧文件，再 cat 回来（hdc file recv 对某些文件会挂住）。
TREE_JSON_DEV="/data/local/tmp/emu-tree.json"
# 临时目录也转成原生形式：bash 认 /tmp，python 不认。
TREE_DIR="$(to_native "${TMPDIR:-/tmp}")"
# 点完等多久再取第二棵树：太快拍到旧帧，太慢错过过渡态。
SETTLE="${SETTLE:-0.8}"
# 录制下来的 UI 路径放在仓库 tmp/routes/ 下：一串「点哪儿」，回放时不用重新摸。
ROUTES_DIR="${EMU_ROUTES_DIR:-$(to_native "$(cd "$SCRIPT_DIR/.." && pwd)/tmp/routes")}"
# 截图落在仓库 tmp/shots/ 下：验收要拿两张图比「屏幕到底变没变」。
SHOT_DIR="${EMU_SHOT_DIR:-$(to_native "$(cd "$SCRIPT_DIR/.." && pwd)/tmp/shots")}"

die() { printf '错误: %s\n' "$1" >&2; exit 1; }

# 设备是否可连。只认 hdc list targets —— Windows 侧 tasklist 匹配不到
# 模拟器进程名（grep emulator/qemu 全空），那条路走不通。
emu_online() {
  "$HDC_BIN" list targets 2>/dev/null | grep -q "$TARGET"
}

# 实例是否还在跑。Emulator.exe -list -details 的 isRunning 不可信：
# 设备在线、端口在监听时它照样报 "false"。唯一靠得住的是 hdc 端口有没有 LISTENING。
emu_running() {
  netstat -ano 2>/dev/null | grep -qE "TCP +$TARGET +[0-9.:]+ +LISTENING"
}

# 等设备真正可连。list targets 里出现还不够 —— 刚起来时 dumpLayout 会报
# need connect-key，必须能成功执行一条 shell 命令才算就绪。
wait_online() {
  local waited=0
  printf '等待设备上线（最长 %ss）' "$BOOT_TIMEOUT"
  while [ "$waited" -lt "$BOOT_TIMEOUT" ]; do
    if emu_online && "$HDC_BIN" shell "echo ok" 2>/dev/null | grep -q ok; then
      printf ' 就绪\n'
      return 0
    fi
    printf '.'
    sleep 3
    waited=$((waited + 3))
  done
  printf ' 超时\n'
  return 1
}

check_density() {
  local raw density vw vh
  raw=$("$HDC_BIN" shell "hidumper -s DisplayManagerService -a -a" 2>/dev/null)
  density=$(printf '%s\n' "$raw" | grep -m1 -oE 'Density: *[0-9.]+' | grep -oE '[0-9.]+')
  vw=$(printf '%s\n' "$raw" | grep -m1 -oE 'VirtualWidth: *[0-9]+' | grep -oE '[0-9]+')
  vh=$(printf '%s\n' "$raw" | grep -m1 -oE 'VirtualHeight: *[0-9]+' | grep -oE '[0-9]+')
  if [ -z "$density" ]; then
    printf '密度: 读不到（设备可能还没准备好）\n'
    return 2
  fi
  printf '密度: %s  视口: %sx%svp\n' "$density" "${vw:-?}" "${vh:-?}"
  if [ "$density" != "$EXPECT_DENSITY" ]; then
    printf '警告: 密度应为 %s，实际 %s —— 整屏 UI 会偏小。\n' "$EXPECT_DENSITY" "$density"
    printf '      鸿蒙没有改密度的口子（wm / param 都不行），只能重启模拟器：\n'
    printf '      bash scripts/emu.sh restart\n'
    return 1
  fi
  return 0
}


# ── 多对话共用模拟器：先查锁，再动手 ──────────────────────────
# 本机同时跑多个对话是常态，模拟器只有一个。锁是「谁在用」的唯一存证。
# 不做进程存活检测 —— emu.sh 每次调用都是短命进程，PID 一退就没意义；
# 改用时间戳 + TTL：超过 LOCK_TTL 分钟没人刷新，视为「可能已放弃」，
# 但脚本不会自动清掉，必须人来确认。
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
LOCK_DIR="$PROJECT_ROOT/tmp/emulator.lock"
LOCK_INFO="$LOCK_DIR/owner"
LOCK_TTL="${EMU_LOCK_TTL:-90}"

is_num() { case "$1" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }
lock_epoch() { sed -n 's/^epoch=//p' "$LOCK_INFO" 2>/dev/null | head -1; }
lock_field() { sed -n "s/^$1=//p" "$LOCK_INFO" 2>/dev/null | head -1; }

# 锁已存在的分钟数；读不到返回空串
lock_age_min() {
  local ep; ep=$(lock_epoch)
  is_num "$ep" || return 0
  printf '%s' $(( ($(date +%s) - ep) / 60 ))
}

lock_owner_desc() {
  printf '%s ｜ 用途: %s ｜ 开始: %s' \
    "$(lock_field session | sed 's/^$/未注明/')" \
    "$(lock_field purpose | sed 's/^$/未注明/')" \
    "$(lock_field since | sed 's/^$/未注明/')"
}

do_who() {
  if [ ! -d "$LOCK_DIR" ]; then
    printf '空闲（无锁）\n'
    return 0
  fi
  local age; age=$(lock_age_min)
  printf '占用中（%s 分钟前）: %s\n' "${age:-?}" "$(lock_owner_desc)"
  if is_num "$age" && [ "$age" -gt "$LOCK_TTL" ]; then
    printf '已超过 %s 分钟 TTL —— 可能已被放弃，但不要自行清掉，先向用户确认。\n' "$LOCK_TTL"
  fi
}

do_claim() {
  local purpose='未注明' session="${EMU_SESSION:-$(whoami 2>/dev/null || printf unknown)}"
  while [ $# -gt 0 ]; do
    case "$1" in
      --for)     purpose="${2:-未注明}"; shift 2 ;;
      --session) session="${2:-$session}"; shift 2 ;;
      *) shift ;;
    esac
  done
  mkdir -p "$PROJECT_ROOT/tmp"
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    printf 'session=%s\npurpose=%s\nsince=%s\nepoch=%s\n' \
      "$session" "$purpose" "$(date '+%Y-%m-%d %H:%M:%S')" "$(date +%s)" > "$LOCK_INFO"
    printf '已占锁: %s\n' "$(lock_owner_desc)"
    return 0
  fi
  printf '模拟器已被占用（%s 分钟前）: %s\n' "$(lock_age_min)" "$(lock_owner_desc)" >&2
  printf '等对方 release 再来，不要抢。查占用: bash scripts/emu.sh who\n' >&2
  return 3
}

do_release() {
  local force=0 me="${EMU_SESSION:-$(whoami 2>/dev/null || printf unknown)}"
  while [ $# -gt 0 ]; do
    case "$1" in
      --force)   force=1; shift ;;
      --session) me="${2:-$me}"; shift 2 ;;
      *) shift ;;
    esac
  done
  if [ ! -d "$LOCK_DIR" ]; then
    printf '本来就空闲（无锁）\n'
    return 0
  fi
  local cur; cur=$(lock_field session)
  if [ "$force" -ne 1 ] && [ "$cur" != "$me" ]; then
    printf '锁不属于本会话（持有者: %s ｜ 本会话: %s）；确信可清再加 --force\n' "${cur:-未注明}" "$me" >&2
    return 3
  fi
  rm -rf "$LOCK_DIR"
  printf '已释放锁\n'
}

# 破坏性动作（start / stop / restart）必须持锁：没锁先 claim，别人的锁就等。
# start/stop/restart 也认 --session，否则认不出持有者会被当成「别人的锁」。
parse_session_flag() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --session) EMU_SESSION="${2:-}"; shift 2 ;;
      *) shift ;;
    esac
  done
}

require_lock() {
  local what="$1"
  if [ ! -d "$LOCK_DIR" ]; then
    printf '%s 需要先占锁: bash scripts/emu.sh claim --for "%s 要做什么"\n' "$what" "$what" >&2
    return 2
  fi
  if [ -n "${EMU_SESSION:-}" ] && [ "$(lock_field session)" = "$EMU_SESSION" ]; then
    return 0
  fi
  local age; age=$(lock_age_min)
  if is_num "$age" && [ "$age" -gt "$LOCK_TTL" ]; then
    printf '锁已 %s 分钟没刷新（TTL %s），持有者: %s\n' "$age" "$LOCK_TTL" "$(lock_owner_desc)" >&2
    printf '先向用户确认，再 release --force 清掉。不要自行推断对方已放弃。\n' >&2
    return 3
  fi
  printf '%s 被另一个对话占用（%s 分钟前）: %s\n' "$what" "${age:-?}" "$(lock_owner_desc)" >&2
  printf '等它 release；不要抢模拟器。\n' >&2
  return 3
}

# 截图不拦，但对方的中间态可能被拍进来，先提示一声。
warn_if_other_holds() {
  [ -d "$LOCK_DIR" ] || return 0
  if [ -n "${EMU_SESSION:-}" ] && [ "$(lock_field session)" = "$EMU_SESSION" ]; then
    return 0
  fi
  printf '提示: 别的对话正持有锁 —— %s（%s 分钟前）。截图可能拍到它的中间态。\n' \
    "$(lock_owner_desc)" "$(lock_age_min)" >&2
}
# 截图。不走 hdc file recv —— 实测它对 JPEG 大文件会挂住不返回；
# 改用 shell base64 取回再本地解码。
# 截一张图到本地路径。后缀必须是 .jpeg —— snapshot_display 对 .png 报 invalid。
take_shot() {
  local out="$1"
  local tmp="/data/local/tmp/cap.jpeg"
  "$HDC_BIN" shell "snapshot_display -f $tmp" >/dev/null 2>&1 || return 1
  "$HDC_BIN" shell "base64 -w 0 $tmp" 2>/dev/null | base64 -d > "$out" 2>/dev/null
  [ -s "$out" ] || return 1
  return 0
}

do_cap() {
  warn_if_other_holds cap
  local out="${1:-$PWD/cap-$(date +%H%M%S).jpeg}"
  case "$out" in /*) ;; *) out="$PWD/$out" ;; esac
  take_shot "$out" || { printf '截图失败\n' >&2; return 1; }
  printf '已保存: %s (%s 字节)\n' "$out" "$(wc -c < "$out" | tr -d ' ')"
}

do_shot() {
  warn_if_other_holds shot
  local name="${1:-shot-$(date +%H%M%S)}"
  emu_online || die "设备不在线：先 emu.sh start"
  mkdir -p "$SHOT_DIR"
  local out="$SHOT_DIR/$name.jpeg"
  take_shot "$out" || { printf '截图失败\n' >&2; return 1; }
  printf '已保存: %s (%s 字节)\n' "$out" "$(wc -c < "$out" | tr -d ' ')"
}

# 比两张图，先回答「屏幕到底变没变」。退出码 0 有变化 / 4 几乎没变。
do_diff() {
  local a="${1:-}" b="${2:-}"
  if [ -z "$a" ] || [ -z "$b" ]; then
    die "用法: emu.sh diff A.jpeg B.jpeg [--min 0.0005] [--thr 16]"
  fi
  shift 2
  "${PYTHON:-python}" "$NAV_PY" shotdiff "$a" "$b" "$@"
}

do_start() {
  require_lock start || return $?
  if emu_online; then
    printf '设备已在线: %s\n' "$TARGET"
    check_density
    return 0
  fi

  # 实例在跑但设备没上线：上一轮启动还没走完，别重复拉起
  if emu_running; then
    printf '实例已在运行但设备未就绪，直接等上线\n'
    wait_online || die "启动超时，看 ${HOME}/AppData/Local/Huawei/Emulator/deployed/$AVD_NAME/Emulator.log"
    check_density
    return 0
  fi

  printf '启动模拟器: %s\n' "$AVD_NAME"
  local log="${TMPDIR:-/tmp}/emu-start.log"
  "$EMU_BIN" -start "$AVD_NAME" > "$log" 2>&1 &
  sleep 5

  if grep -qiE 'Permission denied|拒绝访问' "$log" 2>/dev/null; then
    printf '模拟器启动被沙箱拒绝：它要写 AppData/Local/Huawei/Emulator/deployed/ 下的镜像文件。\n' >&2
    printf '请以 danger-full-access 权限重跑本脚本。原始日志: %s\n' "$log" >&2
    return 1
  fi

  wait_online || die "启动超时，看 $log 与 .../deployed/$AVD_NAME/Emulator.log"
  check_density
}

do_stop() {
  require_lock stop || return $?
  if ! emu_running; then
    printf '实例已停止: %s\n' "$AVD_NAME"
    return 0
  fi
  "$EMU_BIN" -stop "$AVD_NAME" >/dev/null 2>&1
  local waited=0
  # 两个条件都要等：设备从 hdc 消失，且端口释放。
  # 只看前者会在进程没退干净时返回，紧接着的 start 会撞上进程锁。
  while [ "$waited" -lt 60 ]; do
    emu_online || { ! emu_running && break; }
    sleep 2
    waited=$((waited + 2))
  done
  if emu_running; then
    printf '仍在运行 —— Emulator.exe -stop 未生效，需要人工从窗口工具栏关。\n' >&2
    return 1
  fi
  printf '已停止: %s\n' "$AVD_NAME"
  return 0
}

do_status() {
  if emu_online; then
    printf '设备: 在线 (%s)\n' "$TARGET"
    check_density
  else
    printf '设备: 离线\n'
    check_density 2>/dev/null || true
  fi
  if emu_running; then
    printf '实例: %s 运行中\n' "$AVD_NAME"
  else
    printf '实例: %s 已停止\n' "$AVD_NAME"
  fi
  if [ -d "$LOCK_DIR" ]; then
    printf '锁: 占用中（%s 分钟前）%s\n' "$(lock_age_min)" "$(lock_owner_desc)"
  else
    printf '锁: 空闲\n'
  fi
}

# ---- 控件树 / 精确点击 ----
# dumpLayout 的每个节点带 bounds（设备像素），取中心点击比截图目测准；
# 图标按钮在树里没有 text 时也只能靠它。解析交给 emu-nav.py。
dump_tree() {
  local out="$1" extra="${2:-}"
  rm -f "$out"
  "$HDC_BIN" shell "uitest dumpLayout -p $TREE_JSON_DEV $extra" >/dev/null 2>&1
  "$HDC_BIN" shell "cat $TREE_JSON_DEV" 2>/dev/null > "$out"
  if [ ! -s "$out" ]; then
    printf '取回布局为空 —— 设备未就绪，或 dumpLayout 被拒（先 emu.sh status）\n' >&2
    return 1
  fi
  return 0
}

do_tree() {
  local mode="list" all=0 extra=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --keys) mode="keys"; extra="-a" ;;
      --all)  all=1 ;;
      *) die "tree: 不认识的参数 $1" ;;
    esac
    shift
  done
  emu_online || die "设备不在线：先 emu.sh start"
  local out="$TREE_DIR/emu-tree.json"
  if ! dump_tree "$out" "$extra"; then
    if [ -n "$extra" ]; then
      printf '加 %s 的 dump 取不到数据，退回普通 dump（属性可能不全）\n' "$extra" >&2
      dump_tree "$out" "" || return 1
    else
      return 1
    fi
  fi
  if [ "$mode" = "keys" ]; then
    "${PYTHON:-python}" "$NAV_PY" keys "$out"
  elif [ "$all" = "1" ]; then
    "${PYTHON:-python}" "$NAV_PY" list "$out" --all
    printf '（--all 的序号含不可点节点，与 tap 的序号不是同一套：要 tap 请用不带 --all 的清单）\n'
  else
    "${PYTHON:-python}" "$NAV_PY" list "$out"
  fi
}

# 拾取目标 -> 点中心 -> 停 SETTLE 秒 -> 再取一棵树比对。
# 点完必比对，因为「点了」和「生效了」是两件事：Toggle 偶发第一次不中、
# 菜单图标按钮点不中也不报错，前后两棵树才是证据。
do_click() {
  local who="$1"; shift
  local settle="$SETTLE" verify="" record="" pixels="" minp="" args=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --settle) settle="$2"; shift 2; continue ;;
      --verify) verify="$2"; shift 2; continue ;;
      --record) record="$2"; shift 2; continue ;;
      --pixels) pixels=1; shift; continue ;;
      --min) minp="$2"; shift 2; continue ;;
      *) args+=("$1"); shift; continue ;;
    esac
  done
  require_lock "$who" || return $?
  emu_online || die "设备不在线：先 emu.sh start"
  local pre="$TREE_DIR/emu-tree-pre.json" post="$TREE_DIR/emu-tree-post.json"
  dump_tree "$pre" || return 1
  local shot_pre="" shot_post=""
  if [ -n "$pixels" ]; then
    mkdir -p "$SHOT_DIR"
    shot_pre="$SHOT_DIR/_pre-$$.jpeg"
    take_shot "$shot_pre" || { printf '前置截图失败\n' >&2; return 1; }
  fi
  local picked rc
  picked=$("${PYTHON:-python}" "$NAV_PY" pick "$pre" "${args[@]}")
  rc=$?
  if [ "$rc" -ne 0 ]; then
    printf '%s\n' "$picked" >&2
    return "$rc"
  fi
  printf '%s\n' "$picked"
  local cx cy
  cx=$(printf '%s\n' "$picked" | sed -n 's/^CENTER //p' | cut -d' ' -f1)
  cy=$(printf '%s\n' "$picked" | sed -n 's/^CENTER //p' | cut -d' ' -f2)
  if [ -z "$cx" ] || [ -z "$cy" ]; then
    printf '没从树里取到中心坐标\n' >&2
    return 1
  fi
  printf '点击 (%s, %s)\n' "$cx" "$cy"
  if ! "$HDC_BIN" shell "uitest uiInput click $cx $cy" >/dev/null 2>&1; then
    printf 'uitest uiInput click 失败 —— 坐标可能已不在屏上（页面变了）\n' >&2
    return 1
  fi
  sleep "$settle"
  dump_tree "$post" || return 1
  if [ -n "$pixels" ]; then
    shot_post="$SHOT_DIR/_post-$$.jpeg"
    if take_shot "$shot_post"; then
      local dargs=() drc=0
      if [ -n "$minp" ]; then dargs=(--min "$minp"); fi
      "${PYTHON:-python}" "$NAV_PY" shotdiff "$shot_pre" "$shot_post" "${dargs[@]}" || drc=$?
      if [ "$drc" -eq 4 ]; then
        printf '注意: 屏幕几乎没变 —— 这一下可能点空了；局部小改动也可能低于阈值，以下面 verify 的文字结果为准\n' >&2
      fi
    else
      printf '后置截图失败\n' >&2
    fi
  fi
  if [ -n "$verify" ]; then
    "${PYTHON:-python}" "$NAV_PY" verify "$pre" "$post" --text "$verify"
  else
    "${PYTHON:-python}" "$NAV_PY" verify "$pre" "$post"
  fi
  if [ -n "$record" ]; then
    local p_label p_idx j
    p_label=$(printf '%s\n' "$picked" | sed -n 's/^LABEL //p')
    p_idx=""
    j=0
    while [ $j -lt ${#args[@]} ]; do
      if [ "${args[$j]}" = "--index" ]; then p_idx="${args[$((j + 1))]}"; fi
      j=$((j + 1))
    done
    if [ -n "$p_idx" ]; then
      "${PYTHON:-python}" "$NAV_PY" routeadd "$ROUTES_DIR/$record.json" --label "$p_label" --index "$p_idx"
    elif [ -n "$p_label" ]; then
      "${PYTHON:-python}" "$NAV_PY" routeadd "$ROUTES_DIR/$record.json" --label "$p_label"
    fi
  fi
}

do_tap() {
  local idx="${1:-}"
  [ -n "$idx" ] || die "用法: emu.sh tap <tree 里的序号> [--settle 秒]"
  shift
  do_click tap --index "$idx" "$@"
}

do_tap_text() {
  local text="${1:-}"
  [ -n "$text" ] || die "用法: emu.sh tap-text <文字> [--contains] [--occurrence N] [--settle 秒]"
  shift
  do_click tap-text --text "$text" --verify "$text" "$@"
}

# 一次命令连点多步：每步取树定位、点、停、再取树比对，任一步找不到就停下并打印当前屏。
# --one-shot 只取一次树，用同一屏的坐标连点（批量开关一类的场景，快；会跳页的步骤不能用它）。
do_tap_seq() {
  local settle="$SETTLE" one_shot=0 record="" specs=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --settle)   settle="$2"; shift 2; continue ;;
      --one-shot) one_shot=1; shift; continue ;;
      --record)   record="$2"; shift 2; continue ;;
      *)          specs+=("$1"); shift; continue ;;
    esac
  done
  [ ${#specs[@]} -gt 0 ] || die "用法: emu.sh tap-seq <序号或文字> [更多...] [--one-shot] [--settle 秒] [--record 名字]"
  require_lock tap-seq || return $?
  emu_online || die "设备不在线：先 emu.sh start"
  local coord="$TREE_DIR/emu-seq-coord.json"
  local cur="$TREE_DIR/emu-seq-cur.json"
  local post="$TREE_DIR/emu-seq-post.json"
  if ! dump_tree "$coord"; then return 1; fi
  cp "$coord" "$cur" 2>/dev/null
  local i=0 total=${#specs[@]} ok=0 rc=0 raw kind val out cx cy
  for raw in "${specs[@]}"; do
    i=$((i + 1))
    if [ "$i" -gt 1 ] && [ "$one_shot" = "0" ]; then
      if ! dump_tree "$coord"; then rc=1; break; fi
      cp "$coord" "$cur" 2>/dev/null
    fi
    case "$raw" in
      [0-9]*) kind="index"; val="$raw" ;;
      *)      kind="text";  val="$raw" ;;
    esac
    out=$("${PYTHON:-python}" "$NAV_PY" pickseq "$coord" "--$kind" "$val" 2>/dev/null)
    cx=$(printf '%s\n' "$out" | sed -n 's/.*CENTER \([0-9][0-9]*\) \([0-9][0-9]*\) LABEL.*/\1/p')
    cy=$(printf '%s\n' "$out" | sed -n 's/.*CENTER \([0-9][0-9]*\) \([0-9][0-9]*\) LABEL.*/\2/p')
    if [ -z "$cx" ] || [ -z "$cy" ]; then
      printf '[%d/%d] 找不到「%s」—— 停在这一步。当前屏可点的：\n' "$i" "$total" "$val"
      "${PYTHON:-python}" "$NAV_PY" list "$coord" | head -30
      rc=1
      break
    fi
    printf '[%d/%d] 点 %s「%s」(%s, %s)\n' "$i" "$total" "$kind" "$val" "$cx" "$cy"
    "$HDC_BIN" shell "uitest uiInput click $cx $cy" >/dev/null 2>&1 || { printf '点击发送失败\n'; rc=1; break; }
    sleep "$settle"
    if ! dump_tree "$post"; then rc=1; break; fi
    if [ "$kind" = "text" ]; then
      "${PYTHON:-python}" "$NAV_PY" verify "$cur" "$post" --text "$val"
    else
      "${PYTHON:-python}" "$NAV_PY" verify "$cur" "$post"
    fi
    cp "$post" "$cur" 2>/dev/null
    ok=$((ok + 1))
    if [ -n "$record" ]; then
      if [ "$kind" = "index" ]; then
        "${PYTHON:-python}" "$NAV_PY" routeadd "$ROUTES_DIR/$record.json" --index "$val"
      else
        "${PYTHON:-python}" "$NAV_PY" routeadd "$ROUTES_DIR/$record.json" --label "$val"
      fi
    fi
  done
  printf '连点结束：%d 步里点到 %d 步\n' "$total" "$ok"
  return "$rc"
}

# 路径回放：把录下来的一串步骤逐步重走。哪一步的目标不在当前屏就停下，并把这一屏可点的列出来。
# 这正是「路径探索成本高」的省法：摸一次、记一次，之后每次都从这条线上接着走。
do_route_play() {
  local name="${1:-}"
  [ -n "$name" ] || die "用法: emu.sh route play <名字> [--settle 秒]"
  shift || true
  local settle="$SETTLE"
  while [ $# -gt 0 ]; do
    case "$1" in
      --settle) settle="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  local f="$ROUTES_DIR/$name.json"
  [ -f "$f" ] || die "没有这个路径：$f（先 emu.sh route list）"
  require_lock route-play || return $?
  emu_online || die "设备不在线：先 emu.sh start"
  local steps="$TREE_DIR/emu-route-steps.txt"
  # Windows 版 python 的 print 用 \r\n 结尾，read 会把 \r 当成目标文字的一部分，必须剥掉。
  "${PYTHON:-python}" "$NAV_PY" routeshow "$f" --machine | tr -d '\r' > "$steps" || return 1
  local total
  total=$(grep -c '^STEP ' "$steps" 2>/dev/null || printf 0)
  local coord="$TREE_DIR/emu-route-coord.json" post="$TREE_DIR/emu-route-post.json"
  local n=0 ok=0 tag num kind val out cx cy
  while read -r tag num kind val; do
    [ "$tag" = "STEP" ] || continue
    [ -n "$num" ] || continue
    n=$((n + 1))
    if ! dump_tree "$coord"; then printf '第 %s 步之前取不到控件树\n' "$num"; break; fi
    out=$("${PYTHON:-python}" "$NAV_PY" pickseq "$coord" "--$kind" "$val" 2>/dev/null)
    cx=$(printf '%s\n' "$out" | sed -n 's/.*CENTER \([0-9][0-9]*\) \([0-9][0-9]*\) LABEL.*/\1/p')
    cy=$(printf '%s\n' "$out" | sed -n 's/.*CENTER \([0-9][0-9]*\) \([0-9][0-9]*\) LABEL.*/\2/p')
    if [ -z "$cx" ] || [ -z "$cy" ]; then
      printf '路径在第 %s 步断了：「%s」不在当前屏。当前屏可点的：\n' "$num" "$val"
      "${PYTHON:-python}" "$NAV_PY" list "$coord" | head -30
      break
    fi
    printf '[%s] 点 %s「%s」(%s, %s)\n' "$num" "$kind" "$val" "$cx" "$cy"
    "$HDC_BIN" shell "uitest uiInput click $cx $cy" >/dev/null 2>&1 || { printf '点击发送失败\n'; break; }
    sleep "$settle"
    if ! dump_tree "$post"; then break; fi
    if [ "$kind" = "text" ]; then
      "${PYTHON:-python}" "$NAV_PY" verify "$coord" "$post" --text "$val"
    fi
    ok=$((ok + 1))
  done < "$steps"
  printf '回放 %s：共 %d 步，走到 %d 步\n' "$name" "$total" "$ok"
}

do_route() {
  local sub="${1:-list}"
  shift || true
  case "$sub" in
    list)
      if [ ! -d "$ROUTES_DIR" ]; then
        printf '还没有录制过路径（%s 不存在）\n' "$ROUTES_DIR"
        return 0
      fi
      local f found=0
      for f in "$ROUTES_DIR"/*.json; do
        [ -e "$f" ] || continue
        found=1
        printf '%s\n' "$(basename "$f" .json)"
      done
      [ "$found" = "1" ] || printf '目录里还没有路径文件\n'
      ;;
    show)
      [ -n "${1:-}" ] || die "用法: emu.sh route show <名字>"
      "${PYTHON:-python}" "$NAV_PY" routeshow "$ROUTES_DIR/$1.json"
      ;;
    check)
      [ -n "${1:-}" ] || die "用法: emu.sh route check <名字>"
      "${PYTHON:-python}" "$NAV_PY" routecheck "$ROUTES_DIR/$1.json"
      ;;
    rm)
      [ -n "${1:-}" ] || die "用法: emu.sh route rm <名字>"
      rm -f "$ROUTES_DIR/$1.json"
      printf '已删 %s\n' "$1"
      ;;
    play)
      do_route_play "${1:-}" "${@:2}"
      ;;
    *)
      die "route: 不认识的子命令 $sub（list|show|check|rm|play）" ;;
  esac
}

case "${1:-status}" in
  start)   shift; parse_session_flag "$@"; do_start ;;
  stop)    shift; parse_session_flag "$@"; do_stop ;;
  restart) shift; parse_session_flag "$@"; require_lock restart && { do_stop; sleep 2; do_start; } ;;
  status)  do_status ;;
  cap)     shift; do_cap "${1:-}" ;;
  shot)    shift; do_shot "$@" ;;
  diff)    shift; do_diff "$@" ;;
  tree)    shift; do_tree "$@" ;;
  tap)     shift; do_tap "$@" ;;
  tap-text) shift; do_tap_text "$@" ;;
  tap-seq)  shift; do_tap_seq "$@" ;;
  route)    shift; do_route "$@" ;;
  claim)   shift; do_claim "$@" ;;
  release) shift; do_release "$@" ;;
  who)     do_who ;;
  *)
     printf '用法: %s {start|stop|restart|status|cap [文件]|shot <名字>|diff <A> <B>|tree [--keys|--all]|tap <序号>|tap-text <文字>|tap-seq <步> [更多]|route {list|play|show|check|rm}|claim [--for 用途]|release [--force]|who} [--session 标识]\n' "$0"
     printf '  --session 或 EMU_SESSION 用来证明「锁是我占的」；不加就按别人的锁处理。\n'
     printf '  tap / tap-text 加 --pixels 会在点击前后各截一张图比对：屏幕没变会打警告（阈值用 --min 调）。\n'
     printf '  tree 列这一屏可点的控件（带序号）；tap / tap-text 按树里的坐标点，点完自动比对前后两棵树。
  tap-seq 一次命令连点多个（默认每步重新取树，--one-shot 用同一屏坐标）；tap / tap-seq 加 --record 名字 会把步骤存进 tmp/routes/名字.json，route play 名字 逐步重走。\n'
     exit 1 ;;
esac
