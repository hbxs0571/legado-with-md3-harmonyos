#!/usr/bin/env bash
# 本机 assembleHap 一键构建脚本。
# DevEco Studio 26.0.0 装在 D 盘；JAVA_HOME 必须指向自带 jbr，否则 PackageHap 报 00308018 spawn java ENOENT。
set -o pipefail

# 两个变量的路径风格必须不同，否则构不过：
#   DEVECO_ROOT 走 bash 风格（/d/...）—— 它要拼进 PATH 与 exec，PATH 只认 POSIX 路径；
#   DEVECO_SDK_HOME 走 Windows 风格（D:/...）—— hvigor 校验它，给 /d/... 报 00303217。
DEVECO_ROOT="${DEVECO_STUDIO_HOME:-/d/Program Files/Huawei/DevEco Studio}"
DEVECO_SDK_WIN="${DEVECO_SDK_HOME:-D:/Program Files/Huawei/DevEco Studio/sdk}"
export DEVECO_SDK_HOME="$DEVECO_SDK_WIN"
export JAVA_HOME="$DEVECO_ROOT/jbr"
export PATH="$JAVA_HOME/bin:$PATH"

cd "$(dirname "$0")/.." || exit 1
exec "$DEVECO_ROOT/tools/hvigor/bin/hvigorw.bat" --no-daemon --mode module \
  -p product=default -p module=entry@default assembleHap "$@"
