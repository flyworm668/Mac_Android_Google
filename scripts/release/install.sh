#!/bin/zsh
# 个人安卓模拟器 · 首次安装
set -euo pipefail

root="$HOME/Library/Application Support/个人安卓模拟器"
runtime="$root/runtime"
downloads="$root/downloads"
sdk="$runtime/sdk"
jdk="$runtime/jdk"
avd="$runtime/avd"
logs="$runtime/instances"
mkdir -p "$downloads" "$jdk" "$sdk/cmdline-tools" "$avd" "$logs"

jdK_url="https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.21%2B9/OpenJDK17U-jdk_aarch64_mac_hotspot_17.0.21_9.tar.gz"
jdK_sha="78b08c7f5a0598242d5719c022e19479cb4a3aa45c37c19726a757a469ed1c15"
tools_url="https://dl.google.com/android/repository/commandlinetools-mac_arm64-15859902_latest.zip"
tools_sha="835b62a26162b229b441d1f6d4680383815a270809eb33522c0d480fa5002c4e"

fetch() {
  local url="$1" out="$2" sha="$3"
  if [[ -f "$out" && "$(shasum -a 256 "$out" | awk '{print $1}')" == "$sha" ]]; then
    print "已存在：$(basename "$out")"
    return 0
  fi
  print "下载：$(basename "$out")"
  curl -fL --retry 5 --retry-all-errors --retry-delay 3 -o "$out" "$url"
  local actual
  actual="$(shasum -a 256 "$out" | awk '{print $1}')"
  if [[ "$actual" != "$sha" ]]; then
    print -u2 "校验失败：$(basename "$out")"
    exit 1
  fi
}

if [[ ! -x "$jdk/current/bin/java" ]]; then
  rm -rf "$jdk/current"
  fetch "$jdK_url" "$downloads/OpenJDK17U-jdk_aarch64_mac_hotspot_17.0.21_9.tar.gz" "$jdK_sha"
  tar -xzf "$downloads/OpenJDK17U-jdk_aarch64_mac_hotspot_17.0.21_9.tar.gz" -C "$jdk"
  jdk_dir="$(find "$jdk" -maxdepth 1 -type d -name 'jdk-*' | head -1)"
  if [[ -z "$jdk_dir" ]]; then
    print -u2 "JDK 解压失败"
    exit 1
  fi
  ln -sfn "$jdk_dir/Contents/Home" "$jdk/current"
fi
if [[ ! -x "$jdk/current/bin/java" ]]; then
  print -u2 "JDK 不可用：$jdk/current"
  exit 1
fi

if [[ ! -x "$sdk/cmdline-tools/latest/bin/sdkmanager" ]]; then
  fetch "$tools_url" "$downloads/commandlinetools-mac_arm64-15859902_latest.zip" "$tools_sha"
  rm -rf "$downloads/cmdline-tools-extracted"
  mkdir -p "$downloads/cmdline-tools-extracted"
  unzip -q "$downloads/commandlinetools-mac_arm64-15859902_latest.zip" -d "$downloads/cmdline-tools-extracted"
  rm -rf "$sdk/cmdline-tools/latest"
  mv "$downloads/cmdline-tools-extracted/cmdline-tools" "$sdk/cmdline-tools/latest"
fi

export JAVA_HOME="$jdk/current"
export ANDROID_SDK_ROOT="$sdk"
export ANDROID_AVD_HOME="$avd"
export PATH="$JAVA_HOME/bin:$PATH"
sdkmanager="$sdk/cmdline-tools/latest/bin/sdkmanager"

print "接受 Android SDK 许可并安装模拟器组件（约 3 GB）"
yes | "$sdkmanager" --sdk_root="$sdk" --licenses >/dev/null || true
if [[ -x "$sdk/emulator/emulator" && -f "$sdk/system-images/android-35/google_apis/arm64-v8a/system.img" && -x "$sdk/platform-tools/adb" ]]; then
  print "模拟器组件已存在，跳过下载"
else
  "$sdkmanager" --sdk_root="$sdk" --install \
    "platform-tools" \
    "emulator" \
    "platforms;android-35" \
    "system-images;android-35;google_apis;arm64-v8a"
fi

if ! "$sdk/cmdline-tools/latest/bin/avdmanager" list avd | grep -q "Name: personal-phone"; then
  print "创建虚拟设备：30 GB 数据盘、8 GB 内存、1920x1200 横屏"
  echo no | "$sdk/cmdline-tools/latest/bin/avdmanager" create avd \
    --name personal-phone \
    --package "system-images;android-35;google_apis;arm64-v8a" \
    --device pixel_7 \
    --force
fi

python3 -I - "$avd/personal-phone.avd/config.ini" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
values = {
    "disk.dataPartition.size": "30G",
    "hw.ramSize": "8192",
    "hw.cpu.ncore": "6",
    "hw.lcd.width": "1920",
    "hw.lcd.height": "1200",
    "hw.lcd.density": "240",
    "hw.lcd.cutout": "false",
    "hw.initialOrientation": "landscape",
    "hw.keyboard": "yes",
    "hw.gpu.enabled": "yes",
    "hw.gpu.mode": "host",
    "showDeviceFrame": "no",
    "skin.dynamic": "yes",
    "PlayStore.enabled": "no",
}
text = path.read_text()
for key, value in values.items():
    if re.search(rf"(?m)^{re.escape(key)}=", text):
        text = re.sub(rf"(?m)^{re.escape(key)}=.*$", f"{key}={value}", text)
    else:
        text += f"{key}={value}\n"
path.write_text(text)
PY

print "安装完成。请打开「个人安卓模拟器.app」或运行 scripts/release/run.sh"
