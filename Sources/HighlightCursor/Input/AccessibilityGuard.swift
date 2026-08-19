import ApplicationServices

enum AccessibilityGuard {
    static func isTrusted() -> Bool { AXIsProcessTrusted() }

    /// 접근성 권한이 없을 때만 시스템 프롬프트를 띄운다.
    /// 이미 신뢰된 상태면 아무것도 하지 않으므로, 권한이 부여된 뒤에는
    /// 실행할 때마다 다이얼로그가 다시 뜨지 않는다.
    static func promptIfNeeded() {
        // 이미 권한이 있으면 프롬프트를 아예 호출하지 않는다.
        guard !AXIsProcessTrusted() else { return }
        // `kAXTrustedCheckOptionPrompt` is imported as a non-concurrency-safe
        // global `var`, so referencing it directly fails Swift 6 strict
        // concurrency. Use its documented string value ("AXTrustedCheckOptionPrompt")
        // as the CFDictionary key instead.
        let opts = ["AXTrustedCheckOptionPrompt": true]
        _ = AXIsProcessTrustedWithOptions(opts as CFDictionary)
    }
}
