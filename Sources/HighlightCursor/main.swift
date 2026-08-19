import AppKit

@MainActor
func launchApp() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}

MainActor.assumeIsolated {
    launchApp()
}
