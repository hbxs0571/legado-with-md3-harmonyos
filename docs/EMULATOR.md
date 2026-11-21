# 模拟器使用说明

本机用 HarmonyOS 模拟器做设备侧验收。本文件记录**怎么起停、怎么截图、怎么判断密度是否正常**，以及这些做法背后的实测依据 —— 踩过的坑不重复踩。

日常操作用 `scripts/emu.sh`：

```bash
bash scripts/emu.sh start      # 启动 + 等设备真正可连 + 自检密度
bash scripts/emu.sh stop       # 停止，等进程退干净
bash scripts/emu.sh restart    # 密度异常时的唯一解法
bash scripts/emu.sh status     # 在线状态 / 密度 / 视口 / 实例状态
bash scripts/emu.sh cap <路径>  # 截图，默认存当前目录
bash scripts/emu.sh tree       # 列这一屏可点的控件（带序号、bounds、字符）
bash scripts/emu.sh tap 3      # 按序号点，点完自动比对前后两棵树
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

**真正的原因是系统设置里的「显示大小缩放」档位，不是配置坏了，也不必重启模拟器。**

路径：`设置 → 显示和亮度 → 字体大小和界面缩放 → 显示大小缩放`，共三档。

两个实测细节：

- **点已选中档无效**：hilog 会打 `ScreenZoomSettings : slider dpi value not change`，档位没变。
- **必须切到别的档再切回原档** 才会真正生效（相当于强制重算一次 dpi）。

改完桌面可能不重排，需要 `hdc shell reboot`。

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

## 多对话共用一台模拟器：先查锁，再动手

本机同时跑多个对话是常态，模拟器只有一台。`scripts/emu.sh` 用一把锁当「谁在用」的存证：

```bash
bash scripts/emu.sh who                                            # 空闲？谁占着？几分钟前？
bash scripts/emu.sh claim --for '上机验 XX' --session <对话标识>
bash scripts/emu.sh release --session <对话标识>
```

- 锁在 `tmp/emulator.lock/owner`（`tmp/` 被 `.gitignore` 忽略），内容是 session / 用途 / 开始时间 / epoch。
- **不做进程存活检测**：`emu.sh` 每次调用都是短命进程，PID 一退出就没有意义。改用时间戳 + TTL（默认 90 分钟，`EMU_LOCK_TTL` 可调）。
- 过期**不会**自动清。`who` 与 `require_lock` 只提示「可能已被放弃」，清锁要人确认后 `release --force` —— 自动清等于替另一个对话判断「它应该跑完了」。
- `start` / `stop` / `restart` 硬拦：没锁报错并给出 claim 命令，别人的锁报错并打印持有者。`cap` 不拦，但别的对话正持锁时会提示一句：截到的可能是对方的中间态。
- 身份靠 `--session` / `EMU_SESSION` 显式传。同一个 Windows 用户下的多个对话默认同名，**不加标识就分不出谁是谁**，`release` 会因此校验失败要求 `--force` —— 这正是该显式传标识的理由。
- `start` / `stop` / `restart` 同样认 `--session`（或 `EMU_SESSION`）：不加的话脚本认不出你是持有者，会按「别人的锁」拒绝，看起来像自己占的锁不认自己。

## 截图

```bash
bash scripts/emu.sh cap out.jpeg
```

为什么不直接 `hdc file recv`：**实测它对 JPEG 大文件会挂住不返回**（两次都超 120 秒，`timeout` 也不生效，只能杀 job）。脚本走 `hdc shell "base64 -w 0 /data/local/tmp/cap.jpeg"` 取回再本地 `base64 -d`，稳定。

另有两个细节：

- `snapshot_display -f` 的文件后缀**必须是 `.jpeg`**，写 `.png` 直接报 `error: fileName ... invalid, suffix must be .jpeg`
- `hdc file recv` 前若用绝对 POSIX 路径（`/n/...`），在 Git Bash 下会被拼成 `<盘符>:\<工程目录>\/n/...`。用相对文件名，或先 `cd` 到目标目录

截图备选：`hdc shell uitest screenCap -p /data/local/tmp/x.png`（这个支持 `.png`）。

## 控件树取坐标：不知道该点哪个、点不准怎么办

截图目测坐标有两个老问题：**图标按钮不知道是干什么的**，**点下去经常没命中** —— 点色块要落进 56×56 的圆才算命中（点标题行无效），Toggle 还会偶发第一次点不中且不报错。`uitest dumpLayout` 给每个节点带 `bounds`，那是设备像素，取中心就精准。

```bash
bash scripts/emu.sh tree                  # 这一屏可点 / 有字的控件，带序号
bash scripts/emu.sh tree --all            # 连没字的节点一起列
bash scripts/emu.sh tree --keys           # 打印 attributes 里实际存在的字段名
bash scripts/emu.sh tap 3                 # 点 tree 里的第 3 项
bash scripts/emu.sh tap-text 搜索          # 按文字找，点它的中心
bash scripts/emu.sh tap-text 搜索 --contains --occurrence 2 --settle 1.2
```

输出形如（最后一列 `C` 表示节点自己 `clickable`）：

```
可点/有字节点 12 个（共 87 个带 bounds 的节点）
  0  Text           书架                        [40,220][300,300]
  1  Button         -                           [1090,2400][1260,2560]  C
```

命中节点本身不可点时，脚本**沿父链上溯**找第一个可点的祖先再取中心 —— 点 `Text` 的父 `Button`，而不是硬点文字本身。

几个取舍都是踩出来的：

- **点完自动复验**：`tap` / `tap-text` 点下后等 `SETTLE`（默认 0.8 秒）再取一棵树，对比前后文字多集，打印「精确命中已消失 / 仍在」以及新出现、消失的文字。因为「点了」和「生效了」是两件事，靠截图对比像素容易把旧帧当成结果。
- **重名不猜**：同一文字命中多处时打印候选并以退出码 4 结束，要求 `--occurrence N` 或改用序号。猜一个点下去，验证记录就失去意义。
- **`tree --keys` 是校准工具**：`dumpLayout` 的属性名在不同组件上并不一致 —— 实测菜单里的图标按钮连 `text` / `description` 都不暴露（见 [VALIDATION.md](VALIDATION.md) 阅读页菜单一节），字段对不上时先看真实字段名，别靠猜。
- **坐标是设备像素，不是 vp**：密度 3.5 时 1vp = 3.5px。`--settle` 太短会拍到旧帧，太长会错过过渡态。

权限与锁：`tree` 只读，不要求持锁（别的对话持锁时提示一句截图可能拍到它的中间态）；`tap` / `tap-text` 会改设备状态，**要持锁**，与 `start` 同级。

`uitest dumpLayout -p <文件> -a`（全属性）本项目此前一直没用过，所以 `tree --keys` 会先试 `-a`，拿不到数据就退回普通 dump 并提示 —— `--keys` 的字段可能不全，以实际输出为准。

## 页面导航：先认区域，再点控件

上机走查用固定顺序，别一上来就全局搜控件：

1. `emu.sh status` 看在线与密度；`tree` 看当前屏有哪些可点项
2. 冷停再起，保证从首屏开始：`hdc shell aa force-stop io.legado.harmony` → `hdc shell aa start -a EntryAbility -b io.legado.harmony`
3. 每跳一层先 `tree` 认这一屏的控件，再用 `tap-text` / `tap` 走，**不靠记住的像素坐标**
4. 点完看脚本打印的「已消失 / 仍在」与新增文字，确认真的换了页面，再继续下一层

已经过验收记录确认的三层路标（**坐标是历史值，只作 sanity check，优先用 `tree`**）：

| 层 | 怎么进 | 证据 |
| --- | --- | --- |
| 书架 | 冷启动首屏 | [VALIDATION.md](VALIDATION.md) 开书不整章滚动一节 |
| 阅读页 | 书架点书 | 同上 |
| 阅读菜单 | 正文中部点一下（历史坐标 `(640,1400)`） | [VALIDATION.md](VALIDATION.md) 样式卡一节 |

更细的逐页路标，等能独占模拟器时走一遍再补 —— 凭记忆写出来的地图比没有更糟。

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
