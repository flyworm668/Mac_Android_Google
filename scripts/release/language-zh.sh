#!/bin/zsh
# 个人安卓模拟器 · 把安卓系统语言改为简体中文
set -euo pipefail
root="$HOME/Library/Application Support/个人安卓模拟器"
adb="$root/runtime/sdk/platform-tools/adb"
"$adb" -s emulator-5554 root >/dev/null 2>&1 || true
"$adb" -s emulator-5554 shell 'setprop persist.sys.locale zh-Hans-CN; setprop persist.sys.language zh; setprop persist.sys.country CN; stop; start'
for _ in {1..40}; do
  if "$adb" -s emulator-5554 shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' | grep -q '^1$'; then
    print "语言已设为简体中文：$("$adb" -s emulator-5554 shell getprop persist.sys.locale | tr -d '\r')"
    exit 0
  fi
  sleep 3
done
print -u2 "设置超时，请确认模拟器已启动后再运行。"
exit 1
