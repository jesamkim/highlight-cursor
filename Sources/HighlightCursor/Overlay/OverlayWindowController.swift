import AppKit

/// 화면별 오버레이 창을 만들고 커서가 속한 화면의 루트 레이어를 찾아주는 컨트롤러.
/// 디스플레이 구성이 바뀌면 `rebuildForCurrentScreens()`로 창을 다시 만든다.
@MainActor
final class OverlayWindowController {
    private var windows: [OverlayWindow] = []

    init() {
        rebuildForCurrentScreens()
    }

    /// 현재 연결된 모든 화면에 대해 오버레이 창을 재생성한다.
    func rebuildForCurrentScreens() {
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.map { OverlayWindow(screen: $0) }
    }

    private func window(forGlobal point: CGPoint) -> OverlayWindow? {
        windows.first { $0.frame.contains(point) }
    }

    /// 전역 좌표가 속한 화면의 루트 레이어와 그 창의 프레임을 반환한다.
    /// 커서가 어떤 창에도 속하지 않으면 `nil`.
    func rootLayer(forGlobal point: CGPoint) -> (layer: CALayer, frame: CGRect)? {
        guard let window = window(forGlobal: point),
              let layer = window.contentView?.layer else { return nil }
        return (layer, window.frame)
    }
}
