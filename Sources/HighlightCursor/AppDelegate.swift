import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let eventMonitor = EventMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("HighlightCursor launched")
        AccessibilityGuard.promptIfNeeded()
        eventMonitor.onMove = { p in NSLog("move \(p.x),\(p.y)") }
        eventMonitor.onClick = { p, kind in NSLog("click \(kind) \(p.x),\(p.y)") }
        eventMonitor.start()
    }
}
