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
do_cap() {
  warn_if_other_holds cap
  local out="${1:-$PWD/cap-$(date +%H%M%S).jpeg}"
  # 后缀必须是 .jpeg，snapshot_display 对 .png 报 invalid
  local tmp="/data/local/tmp/cap.jpeg"
  case "$out" in /*) ;; *) out="$PWD/$out" ;; esac
  "$HDC_BIN" shell "snapshot_display -f $tmp" >/dev/null 2>&1 \
    || { printf 'snapshot_display 失败\n' >&2; return 1; }
  "$HDC_BIN" shell "base64 -w 0 $tmp" 2>/dev/null | base64 -d > "$out" 2>/dev/null
  [ -s "$out" ] || { printf '截图解码失败\n' >&2; return 1; }
  printf '已保存: %s (%s 字节)\n' "$out" "$(wc -c < "$out" | tr -d ' ')"
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

case "${1:-status}" in
  start)   shift; parse_session_flag "$@"; do_start ;;
  stop)    shift; parse_session_flag "$@"; do_stop ;;
  restart) shift; parse_session_flag "$@"; require_lock restart && { do_stop; sleep 2; do_start; } ;;
  status)  do_status ;;
  cap)     shift; do_cap "${1:-}" ;;
  claim)   shift; do_claim "$@" ;;
  release) shift; do_release "$@" ;;
  who)     do_who ;;
  *)
     printf '用法: %s {start|stop|restart|status|cap [文件]|claim [--for 用途]|release [--force]|who} [--session 标识]\n' "$0"
     printf '  --session 或 EMU_SESSION 用来证明「锁是我占的」；不加就按别人的锁处理。\n'
     exit 1 ;;
esac
