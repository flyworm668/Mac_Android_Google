#!/bin/zsh
# 个人安卓模拟器 · 切换模拟器窗口全屏
set -euo pipefail
osascript <<'APPLESCRIPT'
tell application "System Events"
  set targetProcess to first process whose name contains "qemu-system"
  set frontmost of targetProcess to true
  keystroke "f" using {command down, shift down}
end tell
APPLESCRIPT
