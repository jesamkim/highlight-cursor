import AppKit

/// 전역 단축키로 각 효과를 켜고 끈다.
/// ⌥⌘H = 하이라이트, ⌥⌘S = 스포트라이트, ⌥⌘T = 트레일.
/// 타이머 없이 `NSEvent.addGlobalMonitorForEvents(matching: .keyDown)`로
/// 키 이벤트가 발생할 때만 콜백을 받는다(폴링 금지).
@MainActor
final class HotkeyManager {
    var onToggleHighlight: (() -> Void)?
    var onToggleSpotlight: (() -> Void)?
    var onToggleTrail: (() -> Void)?
    private var monitor: Any?

    func start() {
        stop()
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated {
                // 키를 길게 누르면 macOS가 .keyDown을 반복 전달한다(auto-repeat).
                // 이를 무시하지 않으면 한 번의 입력이 여러 번 토글되어
                // 릴리스 시점에 따라 결과가 비결정적으로 보인다.
                guard !event.isARepeat else { return }
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                guard flags.contains(.option), flags.contains(.command) else { return }
                switch event.keyCode {
                case 4:  self?.onToggleHighlight?()   // H
                case 1:  self?.onToggleSpotlight?()   // S
                case 17: self?.onToggleTrail?()       // T
                default: break
                }
            }
        }
    }

    func stop() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }
}
