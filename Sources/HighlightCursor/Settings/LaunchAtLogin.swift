import Foundation

/// macOS 로그인 시 자동 실행을 `~/Library/LaunchAgents/`의 LaunchAgent plist로 관리한다.
/// `SMAppService`(서명 필요) 대신 이 방식을 쓰는 이유: 우리 앱은 ad-hoc 서명이라
/// `SMAppService` 등록이 불안정할 수 있고, LaunchAgent plist는 서명 여부와 무관하게
/// 안정적으로 동작한다.
enum LaunchAtLogin {
    private static let label = "com.jesamkim.highlightcursor.launchagent"

    private static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    /// 현재 로그인 시 자동 실행이 등록돼 있는지 확인한다(plist 존재 여부로 판단).
    static func isEnabled() -> Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    /// 자동 실행을 켜거나 끈다. 켤 때는 현재 실행 중인 `.app` 번들 경로를
    /// 사용해 plist를 쓰고 `launchctl load`로 즉시 등록한다.
    /// - Returns: 성공 여부.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        enabled ? enable() : disable()
    }

    private static func enable() -> Bool {
        guard let appPath = currentAppBundlePath() else { return false }
        let executablePath = appPath + "/Contents/MacOS/HighlightCursor"

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            "KeepAlive": false,
        ]

        do {
            let dir = plistURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: plistURL, options: .atomic)
        } catch {
            NSLog("LaunchAtLogin: failed to write plist: \(error)")
            return false
        }

        let loadStatus = runLaunchctl(["load", plistURL.path])
        guard loadStatus == 0 else {
            // 등록 실패: plist만 남아 있으면 isEnabled()가 잘못 성공으로 판단하므로
            // 지워서 체크박스 상태와 실제 등록 상태가 어긋나지 않게 한다.
            NSLog("LaunchAtLogin: launchctl load exited \(loadStatus), rolling back")
            try? FileManager.default.removeItem(at: plistURL)
            return false
        }
        return true
    }

    private static func disable() -> Bool {
        _ = runLaunchctl(["unload", plistURL.path])
        try? FileManager.default.removeItem(at: plistURL)
        return true
    }

    /// 현재 실행 중인 `.app` 번들의 경로를 얻는다(`Bundle.main.bundlePath`).
    private static func currentAppBundlePath() -> String? {
        let path = Bundle.main.bundlePath
        return path.hasSuffix(".app") ? path : nil
    }

    @discardableResult
    private static func runLaunchctl(_ args: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            NSLog("LaunchAtLogin: launchctl \(args.joined(separator: " ")) failed: \(error)")
            return -1
        }
    }
}
