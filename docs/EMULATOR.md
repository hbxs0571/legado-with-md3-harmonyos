# 模拟器使用说明

本机用 HarmonyOS 模拟器做设备侧验收。本文件记录**怎么起停、怎么截图、怎么判断密度是否正常**，以及这些做法背后的实测依据 —— 踩过的坑不重复踩。

日常操作用 `scripts/emu.sh`：

```bash
bash scripts/emu.sh start      # 启动 + 等设备真正可连 + 自检密度
bash scripts/emu.sh stop       # 停止，等进程退干净
bash scripts/emu.sh restart    # 密度异常时的唯一解法
bash scripts/emu.sh status     # 在线状态 / 密度 / 视口 / 实例状态
bash scripts/emu.sh cap <路径>  # 截图，默认存当前目录
```

目标设备：`Mate 90 Pro`（`127.0.0.1:5555`，API 26，1280×2832，560dpi → **Density 3.5**、视口 365×809vp），包 `io.legado.harmony`。

## 密度：最容易被误判成「应用写死了尺寸」的问题

模拟器跑一段时间后，系统密度会从 3.5 掉到 **1.5**，整屏 UI 明显偏小（字更小、留白更多）。这不是应用的错，配置也没坏：

| | 正常 | 异常 |
| --- | --- | --- |
| DMS `Density` | 3.5 | 1.5 |
| `VirtualWidth × VirtualHeight` | 365×809vp | 853×1888vp |
| 「书架」标题实测高度 | 115px | 49px |

查当前值：

```bash
hdc shell "hidumper -s DisplayManagerService -a -a" | grep -E 'Density|VirtualWidth|VirtualHeight'
```

**`scripts/emu.sh` 每次 start 都会自检这一项，不等于 `3.5` 就报警。**

排查时已确认过、走不通的路（别再试）：

- `wm size` / `wm density` —— 鸿蒙没有这两个命令
- `param set persist.sys.density`（`errNum 1001`）、`const.product.density`（`errNum 106`），以及 `persist.sys.display.density`、`ro.sf.lcd_density`、`debug.dms.density` 等十余个键 —— 全部失败
- `hidumper -s DisplayManagerService` 没有 set density 子命令
- 模拟器配置本身是好的：`config.ini` 与 `hardware-qemu.ini` 都是 `hw.lcd.density=560`，`Emulator.log` 每次启动都记 `Init Phone dpi = 560`
- 应用里没有改密度的代码：`setDefaultDisplayDensity` / `densityDPI` / `@ohos.display` 全 0 命中

**唯一解法是重启模拟器**，重启后自愈。

## 启动必须给足权限

`Emulator.exe -start` 要写 `C:/Users/<user>/AppData/Local/Huawei/Emulator/deployed/<name>/*.qcow2`。在受限沙箱下会失败：

```
Emulator.exe: Could not create '.../cache.img.qcow2': Permission denied
Emulator.exe: -drive ... system.img.qcow2 ...: 拒绝访问。
```

需要以 full-access 权限运行。脚本会识别这个错误并给出提示。

另有一个反直觉之处：带足权限重跑后可能报 `this emulator instance is already running` —— 那是因为**上一次失败的启动其实已经把进程锁留下了**，此时用 `hdc list targets` 查，设备往往已经在启动中。`emu.sh` 用端口监听状态判断，不会撞这个坑。

## 判断设备在不在，不要信这三样

| 手段 | 为什么不能用 |
| --- | --- |
| `tasklist \| grep -i emulator\|qemu` | Windows 侧**匹配不到**模拟器进程名，永远空 |
| `Emulator.exe -list -details` 的 `isRunning` | 设备在线、5555 端口在监听时它照样报 `"false"` |
| `Emulator.exe -list` 有无输出 | 不管实例在不在跑都会列出来 |

**可靠信号只有两个**：`hdc list targets` 里有目标串（设备可连）、`netstat` 里 `127.0.0.1:5555` 处于 `LISTENING`（进程还在）。

而且「可连」不等于「就绪」：刚启动时 `uitest dumpLayout` 会直接报 `[Fail]ExecuteCommand need connect-key? please confirm a device by help info`。要能成功执行一条 `hdc shell "echo ok"` 才算真正可用 —— `emu.sh` 的 `wait_online` 就是按这个判定。

## 截图

```bash
bash scripts/emu.sh cap out.jpeg
```

为什么不直接 `hdc file recv`：**实测它对 JPEG 大文件会挂住不返回**（两次都超 120 秒，`timeout` 也不生效，只能杀 job）。脚本走 `hdc shell "base64 -w 0 /data/local/tmp/cap.jpeg"` 取回再本地 `base64 -d`，稳定。

另有两个细节：

- `snapshot_display -f` 的文件后缀**必须是 `.jpeg`**，写 `.png` 直接报 `error: fileName ... invalid, suffix must be .jpeg`
- `hdc file recv` 前若用绝对 POSIX 路径（`/n/...`），在 Git Bash 下会被拼成 `N:\HarmonyProjects\/n/...`。用相对文件名，或先 `cd` 到目标目录

截图备选：`hdc shell uitest screenCap -p /data/local/tmp/x.png`（这个支持 `.png`）。

## 常用设备命令

```bash
HDC="/d/Program Files/Huawei/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe"

"$HDC" shell "aa start -a EntryAbility -b io.legado.harmony"   # 起应用
"$HDC" shell "aa force-stop io.legado.harmony"                 # 冷停
"$HDC" shell uitest dumpLayout -p /data/local/tmp/x.json       # 组件树
"$HDC" shell "uitest uiInput click 640 1500"                   # 点击
"$HDC" file install -r <本地.hap> /data/local/tmp/a.hap && \
  "$HDC" shell "bm install -r -p /data/local/tmp/a.hap"        # 装包
```

装包也可以用 `hdc -t 127.0.0.1:5555 install -r <hap>`。

偏好文件在 `/data/app/el2/100/base/io.legado.harmony/haps/entry/preferences/`，模拟器上没有 `run-as`，改单个键用 `sed` 就地改后 `cp` 覆盖（新建文件会 `Permission denied`）。

## 构建

```bash
bash scripts/build-hap.sh
```

`hvigor ENOENT` 多半不是真的缺文件，而是 spawn 被沙箱拒绝后吞成的假错误（见 [验证记录](history/validation/2026-10-31-reading-config-ki-rounds.md)）。要 `JAVA_HOME` 指向 DevEco 自带的 `jbr`，并以 full-access 权限运行。增量编译会 UP-TO-DATE 蒙混，`touch` 目标文件可强制重编。详见[构建说明](BUILDING.md)。
