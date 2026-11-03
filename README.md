# 个人安卓模拟器

面向 Apple M5 的免费本机安卓模拟器。它使用 Eclipse Temurin JDK 和 Google 官方 arm64 Android Emulator，不包含、不反编译、不复制 MuMuPlayer。

## 已完成

- 已下载并校验 Temurin JDK 17.0.21+9。
- 已下载并校验 Android command-line tools `15859902`。
- 两份压缩包位于 `downloads/`，已解压到 `runtime/`。

## 继续安装

安装模拟器与 Android 15 镜像需要运行 Google 官方 `sdkmanager`：

```zsh
./scripts/install-runtime.sh
./scripts/self-check.sh
```

镜像大约需要数 GB 磁盘空间和下载时间。安装完成后构建启动器：

```zsh
swift build
swift run PersonalAndroidEmulator
```

把 APK 拖进启动器窗口即可安装。游戏 APK 不由本项目下载。
