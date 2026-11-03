#!/bin/zsh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
failures=0
check() {
  if [[ -e "$1" ]]; then
    print "OK  $2"
  else
    print "缺  $2"
    failures=$((failures + 1))
  fi
}

check "$root/runtime/jdk/current/bin/java" "JDK 17"
check "$root/runtime/sdk/cmdline-tools/latest/bin/sdkmanager" "sdkmanager"
check "$root/runtime/sdk/platform-tools/adb" "adb"
check "$root/runtime/sdk/emulator/emulator" "Android Emulator"
check "$root/runtime/sdk/system-images/android-35/google_apis/arm64-v8a/system.img" "Android 15 arm64 镜像"
check "$root/runtime/avd/personal-phone.avd/config.ini" "personal-phone 虚拟设备"
exit "$failures"
