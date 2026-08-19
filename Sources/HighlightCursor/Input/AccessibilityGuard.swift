import ApplicationServices

enum AccessibilityGuard {
    static func isTrusted() -> Bool { AXIsProcessTrusted() }

    static func promptIfNeeded() {
        // `kAXTrustedCheckOptionPrompt` is imported as a non-concurrency-safe
        // global `var`, so referencing it directly fails Swift 6 strict
        // concurrency. Use its documented string value ("AXTrustedCheckOptionPrompt")
        // as the CFDictionary key instead.
        let opts = ["AXTrustedCheckOptionPrompt": true]
        _ = AXIsProcessTrustedWithOptions(opts as CFDictionary)
    }
}
