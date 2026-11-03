#!/bin/zsh
# 个人安卓模拟器 · 启动（30 GB 数据盘 / 8 GB 内存 / 简体中文）
set -euo pipefail
root="$HOME/Library/Application Support/个人安卓模拟器"
export ANDROID_SDK_ROOT="$root/runtime/sdk"
export ANDROID_AVD_HOME="$root/runtime/avd"
export JAVA_HOME="$root/runtime/jdk/current"
exec "$ANDROID_SDK_ROOT/emulator/emulator" -avd personal-phone \
  -skin 1920x1080 -gpu host -feature GLESDynamicVersion,GuestAngle \
  -memory 8192 -no-metrics "$@"
