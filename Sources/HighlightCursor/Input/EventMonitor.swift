import AppKit

enum ClickKind { case left, right }

@MainActor
final class EventMonitor {
    var onMove: ((CGPoint) -> Void)?
    var onClick: ((CGPoint, ClickKind) -> Void)?
    private var monitor: Any?

    func start() {
        stop()
        monitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            // The global monitor closure is delivered on the main thread by AppKit.
            MainActor.assumeIsolated {
                guard let self else { return }
                let loc = NSEvent.mouseLocation
                switch event.type {
                case .leftMouseDown: self.onClick?(loc, .left)
                case .rightMouseDown: self.onClick?(loc, .right)
                default: self.onMove?(loc)
                }
            }
        }
    }

    func stop() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }
}
