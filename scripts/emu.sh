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

# 截图。不走 hdc file recv —— 实测它对 JPEG 大文件会挂住不返回；
# 改用 shell base64 取回再本地解码。
do_cap() {
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
}

case "${1:-status}" in
  start)   do_start ;;
  stop)    do_stop ;;
  restart) do_stop; sleep 2; do_start ;;
  status)  do_status ;;
  cap)     shift; do_cap "${1:-}" ;;
  *) printf '用法: %s {start|stop|restart|status|cap [文件]}\n' "$0"; exit 1 ;;
esac
