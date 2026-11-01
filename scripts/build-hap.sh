#!/usr/bin/env bash
# 本机 assembleHap 一键构建脚本。
# DevEco Studio 26.0.0 装在 D 盘；JAVA_HOME 必须指向自带 jbr，否则 PackageHap 报 00308018 spawn java ENOENT。
set -o pipefail

DEVECO_ROOT="${DEVECO_STUDIO_HOME:-/d/Program Files/Huawei/DevEco Studio}"
export DEVECO_SDK_HOME="$DEVECO_ROOT/sdk"
export JAVA_HOME="$DEVECO_ROOT/jbr"
export PATH="$JAVA_HOME/bin:$PATH"

cd "$(dirname "$0")/.." || exit 1
exec "$DEVECO_ROOT/tools/hvigor/bin/hvigorw.bat" --no-daemon --mode module \
  -p product=default -p module=entry@default assembleHap "$@"
