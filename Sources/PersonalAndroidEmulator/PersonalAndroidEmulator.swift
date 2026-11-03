import SwiftUI
import UniformTypeIdentifiers

@main
struct PersonalAndroidEmulatorApp: App {
    @StateObject private var controller = EmulatorController()

    var body: some Scene {
        WindowGroup("个人安卓模拟器") {
            ContentView(controller: controller)
                .frame(minWidth: 680, minHeight: 420)
        }
    }
}

struct ContentView: View {
    @ObservedObject var controller: EmulatorController
    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("个人安卓模拟器")
                .font(.largeTitle.bold())
            Text("Android 15 · arm64 · 1920×1080 横屏 · Apple M5 GPU 加速")
                .foregroundStyle(.secondary)
            Text(controller.status)
                .textSelection(.enabled)
            HStack {
                Button(controller.isRunning ? "运行中" : "启动模拟器") { controller.start() }
                    .disabled(controller.isRunning || controller.isBusy)
                Button("明日方舟") { controller.launchGame(package: "com.hypergryph.arknights", needsOpenGL: true) }
                    .disabled(controller.isBusy)
                Button("阴阳师") { controller.launchGame(package: "com.netease.onmyoji", needsOpenGL: false) }
                    .disabled(controller.isBusy)
                Button("关闭") { controller.stop() }
                    .disabled(!controller.isRunning)
                Button("检查环境") { controller.refresh() }
                Button(controller.isFullscreen ? "退出全屏" : "全屏") { controller.toggleFullscreen() }
            }
            .buttonStyle(.borderedProminent)
            Text(isTargeted ? "松开以安装 APK" : "把 APK 拖到这里，或使用下方按钮选择")
                .frame(maxWidth: .infinity, minHeight: 120)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(isTargeted ? Color.accentColor : .clear, lineWidth: 2))
            Button("选择 APK") { chooseAPK() }
                .disabled(controller.isBusy)
            Text("两个游戏使用不同的图形路径，切换游戏会重启模拟器。明日方舟走 OpenGL 以避开更新卡死，阴阳师走 Vulkan 以获得 OpenGL ES 3.1。")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("游戏 APK 由你自行提供。模拟器不会伪装成真机，也不会绕过游戏检测。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .onAppear { controller.refresh() }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url, url.pathExtension.lowercased() == "apk" else { return }
                Task { @MainActor in controller.install(apk: url) }
            }
            return true
        }
    }

    private func chooseAPK() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "apk") ?? .data]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            controller.install(apk: url)
        }
    }
}
