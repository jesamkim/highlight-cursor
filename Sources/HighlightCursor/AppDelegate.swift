import AppKit
import HighlightCursorCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let eventMonitor = EventMonitor()
    private let store = SettingsStore()
    private lazy var overlayController = OverlayWindowController()
    private lazy var coordinator = EffectCoordinator(controller: overlayController, store: store)
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("HighlightCursor launched")
        AccessibilityGuard.promptIfNeeded()

        // 오버레이·코디네이터를 지연 초기화 프로퍼티에서 강제 생성한다.
        _ = coordinator

        // 메뉴바 아이콘 + 효과 토글 + 종료 메뉴. 토글 시 코디네이터에 반영한다.
        menuBar = MenuBarController(store: store) { [weak self] in
            self?.coordinator.refreshSettings()
        }

        // 시작 시 UserDefaults에 저장된 이전 상태(어떤 효과가 켜져 있었는지)를
        // 즉시 복원한다. 마우스를 움직이기 전에도 하이라이트/스포트라이트가
        // 저장된 대로 보이게 한다.
        coordinator.refreshSettings()

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
