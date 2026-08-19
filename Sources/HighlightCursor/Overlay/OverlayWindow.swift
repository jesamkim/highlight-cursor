import AppKit

/// 화면 하나를 덮는 투명·클릭통과 오버레이 창.
/// 사용자의 실제 클릭을 절대 가로막지 않도록 `ignoresMouseEvents = true`이며,
/// 스크린세이버 레벨에 떠 있고 layer-backed `contentView`를 루트로 둔다.
@MainActor
final class OverlayWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(contentRect: screen.frame,
                   styleMask: .borderless,
                   backing: .buffered,
                   defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        let view = NSView(frame: screen.frame)
        view.wantsLayer = true
        contentView = view

        setFrame(screen.frame, display: true)
        orderFrontRegardless()
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
