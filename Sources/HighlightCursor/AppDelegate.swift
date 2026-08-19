import AppKit
import HighlightCursorCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let eventMonitor = EventMonitor()
    private let store = SettingsStore()
    private lazy var overlayController = OverlayWindowController()
    private lazy var coordinator = EffectCoordinator(controller: overlayController, store: store)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("HighlightCursor launched")
        AccessibilityGuard.promptIfNeeded()

        // 오버레이·코디네이터를 지연 초기화 프로퍼티에서 강제 생성한다.
        _ = coordinator

        eventMonitor.onMove = { [weak self] point in
            self?.coordinator.handleMove(global: point)
        }
        eventMonitor.onClick = { [weak self] point, kind in
            self?.coordinator.handleClick(global: point, kind: kind)
        }
        eventMonitor.start()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.overlayController.rebuildForCurrentScreens()
            }
        }
    }
}
