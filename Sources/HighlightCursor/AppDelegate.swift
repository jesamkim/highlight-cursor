import AppKit
import HighlightCursorCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let eventMonitor = EventMonitor()
    private let store = SettingsStore()
    private lazy var overlayController = OverlayWindowController()
    private lazy var coordinator = EffectCoordinator(controller: overlayController, store: store)
    private var menuBar: MenuBarController?
    private let hotkeys = HotkeyManager()

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

        // 전역 단축키(⌥⌘H/S/T): 설정을 바꾸고 코디네이터·메뉴바 체크마크를 함께 갱신한다.
        hotkeys.onToggleHighlight = { [weak self] in self?.toggle { $0.highlightEnabled.toggle() } }
        hotkeys.onToggleSpotlight = { [weak self] in self?.toggle { $0.spotlightEnabled.toggle() } }
        hotkeys.onToggleTrail = { [weak self] in self?.toggle { $0.trailEnabled.toggle() } }
        hotkeys.start()

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

    /// 설정 필드 하나를 뮤테이션한 뒤 저장하고, 코디네이터와 메뉴바 체크마크를
    /// 함께 갱신한다. 메뉴 토글과 단축키가 이 하나의 경로를 공유해 상태가
    /// 항상 일치한다.
    private func toggle(_ mutate: (inout Settings) -> Void) {
        var s = store.settings
        mutate(&s)
        store.settings = s
        coordinator.refreshSettings()
        menuBar?.refreshMenu()
    }
}
