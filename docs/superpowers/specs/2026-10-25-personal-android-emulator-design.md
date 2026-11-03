# 个人安卓模拟器设计

日期：2026-10-25

## 目标

在 Apple M5 Mac 上提供一个免费、本机使用的安卓模拟器，用于横屏运行本地 APK，优先照顾《阴阳师》和《明日方舟》的帧率与键鼠操作。浏览器通过安装浏览器 APK 获得，不单独开发。

## 边界

- 不反编译、复制或再分发 MuMuPlayer 的程序、资源和实现。界面功能参考其公开使用方式，代码全部重新编写。
- 不下载游戏 APK，不绕过游戏的模拟器检测，也不伪装成真实手机。
- 运行环境使用 Eclipse Temurin JDK 17 和 Google 官方 Android SDK 组件。
- 第一版只同时运行一台虚拟设备。

## 架构

SwiftUI 启动器负责状态、下载安装、创建 AVD、开关机和 APK 安装。Google Android Emulator 负责 arm64 虚拟化与图形加速，使用 Apple Hypervisor.framework 和主机 GPU。

项目运行时固定为：

- `runtime/jdk/current`：Temurin 17.0.21+9
- `runtime/sdk`：Android SDK
- `runtime/avd`：虚拟设备目录
- `runtime/instances`：模拟器进程日志

默认设备：

- 名称：`personal-phone`
- 系统：`system-images;android-35;google_apis;arm64-v8a`
- 画面：1920×1080，420 dpi，横屏
- 资源：6 GB 内存、6 核 CPU、主机 GPU
- 输入：启用硬件键盘；鼠标由模拟器窗口映射为触控

## 组件来源

- JDK：`OpenJDK17U-jdk_aarch64_mac_hotspot_17.0.21_9.tar.gz`
  - SHA-256：`78b08c7f5a0598242d5719c022e19479cb4a3aa45c37c19726a757a469ed1c15`
- SDK 工具：`commandlinetools-mac_arm64-15859902_latest.zip`
  - SHA-256：`835b62a26162b229b441d1f6d4680383815a270809eb33522c0d480fa5002c4e`
- 后续由官方 `sdkmanager` 安装 `platform-tools`、`emulator`、`platforms;android-35` 和 Android 15 arm64 Google APIs 镜像。

## 验收

1. `scripts/self-check.sh` 确认 JDK、模拟器、adb、系统镜像和 AVD 都存在。
2. 启动器能打开模拟器窗口并让 `adb` 看到 `emulator-5554`。
3. 拖入或选择一个本地 APK 后，应用出现在安卓桌面并可启动。
4. 模拟器使用主机 GPU，配置为 1920×1080 横屏。
