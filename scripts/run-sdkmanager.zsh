#!/bin/zsh
set -euo pipefail
root="/Users/hank/test/personal-android-emulator"
export JAVA_HOME="$root/runtime/jdk/current"
export ANDROID_SDK_ROOT="$root/runtime/sdk"
export PATH="$JAVA_HOME/bin:$PATH"
sdkmanager="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager"
yes | "$sdkmanager" --sdk_root="$ANDROID_SDK_ROOT" --licenses >/dev/null || true
"$sdkmanager" --sdk_root="$ANDROID_SDK_ROOT" --install \
  "platform-tools" \
  "emulator" \
  "platforms;android-35" \
  "system-images;android-35;google_apis;arm64-v8a"
