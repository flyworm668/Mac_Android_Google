import AppKit
import Foundation

@MainActor
final class EmulatorController: ObservableObject {
    @Published var status = "正在检查运行环境"
    @Published var isBusy = false
    @Published var isRunning = false
    @Published var isFullscreen = false
    private let paths = RuntimePaths.locate()
    private var emulatorProcess: Process?

    func refresh() {
        let checks = [
            paths.java.path,
            paths.emulator.path,
            paths.adb.path,
            paths.avdHome.appending(path: "personal-phone.avd/config.ini").path
        ]
        let missing = checks.filter { !FileManager.default.fileExists(atPath: $0) }
        status = missing.isEmpty ? "运行环境已就绪" : "运行环境未完成，请先运行 scripts/install-runtime.sh"
    }

    private func record(_ event: String, details: String = "") {
        do {
            try FileManager.default.createDirectory(at: paths.logs, withIntermediateDirectories: true)
            let logURL = paths.logs.appending(path: "errors.log")
            if !FileManager.default.fileExists(atPath: logURL.path) {
                FileManager.default.createFile(atPath: logURL.path, contents: nil)
            }
            let stamp = ISO8601DateFormatter().string(from: Date())
            let body = details.isEmpty ? "" : "\n" + details.suffix(4000)
            let entry = "[\(stamp)] \(event)\(body)\n"
            let handle = try FileHandle(forWritingTo: logURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(entry.utf8))
        } catch {
            status = "错误日志写入失败：\(error.localizedDescription)"
        }
    }

    // 两个游戏对图形路径的要求相反，只能在启动时二选一。
    // 阴阳师的 NeoX 引擎要求 OpenGL ES 3.1，必须开 GuestAngle 走 Vulkan 合成。
    // 明日方舟在这条路径上会因 MoltenVK 的 present fence 死锁卡在获取更新，
    // 关掉 GuestAngle 退回 OpenGL ES 3.0 合成才能继续。
    private enum GraphicsProfile {
        case guestAngle
        case opengl

        var featureFlag: String {
            switch self {
            case .guestAngle: return "GLESDynamicVersion,GuestAngle"
            case .opengl: return "GLESDynamicVersion,-GuestAngle"
            }
        }
    }

    func start() {
        launch(profile: .guestAngle, thenOpen: nil)
    }

    func launchGame(package: String, needsOpenGL: Bool) {
        launch(profile: needsOpenGL ? .opengl : .guestAngle, thenOpen: package)
    }

    private func launch(profile: GraphicsProfile, thenOpen packageName: String?) {
        if emulatorProcess?.isRunning == true {
            emulatorProcess?.terminate()
            emulatorProcess = nil
            isRunning = false
        }
        do {
            try FileManager.default.createDirectory(at: paths.logs, withIntermediateDirectories: true)
            let logURL = paths.logs.appending(path: "emulator.log")
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
            let output = try FileHandle(forWritingTo: logURL)
            let process = Process()
            process.executableURL = paths.emulator
            process.arguments = ["-avd", "personal-phone", "-skin", "1920x1080", "-gpu", "host", "-feature", profile.featureFlag, "-memory", "8192", "-no-snapshot-save", "-no-metrics"]
            process.environment = ProcessInfo.processInfo.environment.merging([
                "ANDROID_SDK_ROOT": paths.sdk.path,
                "ANDROID_AVD_HOME": paths.avdHome.path,
                "JAVA_HOME": paths.root.appending(path: "runtime/jdk/current").path
            ]) { _, new in new }
            process.standardOutput = output
            process.standardError = output
            process.terminationHandler = { [weak self] process in
                Task { @MainActor in
                    self?.isRunning = false
                    if process.terminationStatus != 0 {
                        self?.record("模拟器异常退出", details: "exit=\(process.terminationStatus)")
                        self?.status = "模拟器异常退出，已写入 runtime/instances/errors.log"
                    }
                }
            }
            try process.run()
            emulatorProcess = process
            isRunning = true
            status = "模拟器正在启动"
            record("模拟器启动", details: profile.featureFlag)
            if let packageName {
                openWhenReady(packageName)
            }
        } catch {
            record("模拟器启动失败", details: error.localizedDescription)
            status = error.localizedDescription
        }
    }

    func toggleFullscreen() {
        // 优先使用 macOS 窗口菜单，不依赖辅助功能权限。
        let menuScript = """
        tell application "System Events"
            set targetProcess to first process whose name contains "qemu-system"
            set frontmost of targetProcess to true
            if (value of attribute "AXFullScreen" of window 1 of targetProcess) is true then
                set value of attribute "AXFullScreen" of window 1 of targetProcess to false
            else
                set value of attribute "AXFullScreen" of window 1 of targetProcess to true
            end if
        end tell
        """
        var errorInfo: NSDictionary?
        _ = NSAppleScript(source: menuScript)?.executeAndReturnError(&errorInfo)
        if errorInfo == nil {
            isFullscreen.toggle()
            status = isFullscreen ? "模拟器已全屏" : "模拟器已退出全屏"
            return
        }

        // 退回模拟器自带快捷键 Ctrl+Alt+F。
        let keyScript = """
        tell application "System Events"
            set targetProcess to first process whose name contains "qemu-system"
            set frontmost of targetProcess to true
            keystroke "f" using {command down, control down}
        end tell
        """
        var keyError: NSDictionary?
        _ = NSAppleScript(source: keyScript)?.executeAndReturnError(&keyError)
        if keyError == nil {
            isFullscreen.toggle()
            status = isFullscreen ? "已向模拟器发送全屏命令" : "已向模拟器发送退出全屏命令"
            return
        }

        let message = (keyError?[NSAppleScript.errorMessage] as? String) ?? "未知错误"
        record("模拟器全屏切换失败", details: message)
        status = "无法控制模拟器窗口：请在系统设置 → 隐私与安全性 → 辅助功能中勾选「个人安卓模拟器」，然后重试。"
    }

    func stop() {
        emulatorProcess?.terminate()
        emulatorProcess = nil
        isRunning = false
        status = "模拟器已关闭"
    }

    func install(apk url: URL) {
        isBusy = true
        status = "正在等待模拟器连接"
        Task {
            do {
                guard try await waitForDevice() else {
                    status = "没有找到已启动的模拟器。请先点击“启动模拟器”，看到安卓桌面后再安装。"
                    isBusy = false
                    return
                }
                status = "正在安装 \(url.lastPathComponent)"
                let result = try CommandRunner.run(paths.adb, arguments: ["-s", "emulator-5554", "install", "-r", "-d", url.path], environment: [
                    "ANDROID_SDK_ROOT": paths.sdk.path
                ])
                if result.status == 0 {
                    status = "安装完成：\(url.lastPathComponent)"
                } else {
                    record("APK 安装失败", details: result.output)
                    status = "安装失败，已写入 runtime/instances/errors.log"
                }
            } catch {
                status = error.localizedDescription
            }
            isBusy = false
        }
    }

    private func openWhenReady(_ packageName: String) {
        isBusy = true
        status = "模拟器正在启动，准备打开游戏"
        Task {
            do {
                guard try await waitForBoot() else {
                    status = "模拟器启动超时，游戏未打开"
                    isBusy = false
                    return
                }
                status = "正在打开游戏"
                let result = try CommandRunner.run(paths.adb, arguments: [
                    "-s", "emulator-5554", "shell", "monkey", "-p", packageName,
                    "-c", "android.intent.category.LAUNCHER", "1"
                ], environment: ["ANDROID_SDK_ROOT": paths.sdk.path])
                status = result.status == 0 ? "游戏已打开" : "游戏打开失败，已写入 runtime/instances/errors.log"
                if result.status != 0 {
                    record("游戏打开失败", details: result.output)
                }
            } catch {
                status = error.localizedDescription
            }
            isBusy = false
        }
    }

    // 等到系统启动完成再拉起游戏，避免开机动画阶段启动失败。
    private func waitForBoot() async throws -> Bool {
        for _ in 0..<90 {
            let result = try CommandRunner.run(paths.adb, arguments: [
                "-s", "emulator-5554", "shell", "getprop", "sys.boot_completed"
            ], environment: ["ANDROID_SDK_ROOT": paths.sdk.path])
            if result.output.trimmingCharacters(in: .whitespacesAndNewlines) == "1" {
                return true
            }
            try await Task.sleep(nanoseconds: 2_000_000_000)
        }
        return false
    }

    private func waitForDevice() async throws -> Bool {
        for _ in 0..<60 {
            let result = try CommandRunner.run(paths.adb, arguments: ["devices"], environment: [
                "ANDROID_SDK_ROOT": paths.sdk.path
            ])
            if result.output.contains("emulator-5554\tdevice") {
                return true
            }
            try await Task.sleep(nanoseconds: 2_000_000_000)
        }
        return false
    }
}
