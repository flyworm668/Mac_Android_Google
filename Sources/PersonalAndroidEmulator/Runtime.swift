import Foundation

struct RuntimePaths {
    let root: URL

    var java: URL { root.appending(path: "runtime/jdk/current/bin/java") }
    var sdk: URL { root.appending(path: "runtime/sdk") }
    var adb: URL { sdk.appending(path: "platform-tools/adb") }
    var emulator: URL { sdk.appending(path: "emulator/emulator") }
    var avdHome: URL { root.appending(path: "runtime/avd") }
    var logs: URL { root.appending(path: "runtime/instances") }

    static func locate() -> RuntimePaths {
        let current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let candidates = [
            current,
            current.appending(path: "personal-android-emulator"),
            URL(fileURLWithPath: "/Users/hank/test/personal-android-emulator"),
            FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support/个人安卓模拟器")
        ]
        let match = candidates.first {
            FileManager.default.fileExists(atPath: $0.appending(path: "runtime/sdk/emulator/emulator").path)
        } ?? candidates.first {
            FileManager.default.fileExists(atPath: $0.appending(path: "Package.swift").path)
        }
        return RuntimePaths(root: match ?? current)
    }
}

enum CommandError: LocalizedError {
    case failed(String, Int32, String)

    var errorDescription: String? {
        switch self {
        case let .failed(command, status, output):
            return "\(command) 退出码 \(status)\n\(output)"
        }
    }
}

struct CommandResult {
    var status: Int32
    var output: String
}

enum CommandRunner {
    static func run(_ executable: URL, arguments: [String], environment: [String: String] = [:]) throws -> CommandResult {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        var env = ProcessInfo.processInfo.environment
        environment.forEach { env[$0] = $1 }
        process.environment = env
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return CommandResult(status: process.terminationStatus, output: String(decoding: data, as: UTF8.self))
    }
}
