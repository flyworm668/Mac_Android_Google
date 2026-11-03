#!/bin/zsh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
export JAVA_HOME="$root/runtime/jdk/current"
export ANDROID_SDK_ROOT="$root/runtime/sdk"
export PATH="$JAVA_HOME/bin:$PATH"

if [[ ! -x "$JAVA_HOME/bin/java" || ! -x "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" ]]; then
  print -u2 "JDK 或 sdkmanager 不存在。先保留已校验的 downloads/ 压缩包，再按 README 解压。"
  exit 1
fi

yes | "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$ANDROID_SDK_ROOT" --licenses >/dev/null || true
"$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$ANDROID_SDK_ROOT" --install \
  "platform-tools" \
  "emulator" \
  "platforms;android-35" \
  "system-images;android-35;google_apis;arm64-v8a"

image="system-images;android-35;google_apis;arm64-v8a"
avd_root="$root/runtime/avd"
mkdir -p "$avd_root"
export ANDROID_AVD_HOME="$avd_root"
if ! "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/avdmanager" list avd | grep -q "Name: personal-phone"; then
  echo no | "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/avdmanager" create avd \
    --name personal-phone \
    --package "$image" \
    --device pixel_7 \
    --force
fi

config="$avd_root/personal-phone.avd/config.ini"
python3 -I - "$config" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
values = {
    "hw.lcd.width": "1920",
    "hw.lcd.height": "1080",
    "hw.lcd.density": "420",
    "hw.ramSize": "6144",
    "hw.cpu.ncore": "6",
    "hw.gpu.enabled": "yes",
    "hw.gpu.mode": "host",
    "hw.keyboard": "yes",
    "hw.initialOrientation": "landscape",
    "hw.keyboard.lid": "no",
    "showDeviceFrame": "no",
    "skin.dynamic": "yes",
}
lines = path.read_text().splitlines()
seen = set()
output = []
for line in lines:
    key = line.split("=", 1)[0]
    if key in values:
        output.append(f"{key}={values[key]}")
        seen.add(key)
    else:
        output.append(line)
for key, value in values.items():
    if key not in seen:
        output.append(f"{key}={value}")
path.write_text("\n".join(output) + "\n")
PY

print "Android 15 arm64 运行环境已安装。"
