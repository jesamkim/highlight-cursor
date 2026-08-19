import Foundation
import HighlightCursorCore

/// Settings 모델과 SettingsStore의 단위 테스트.
/// 부모(테스트 러너)가 `runSettingsTests()`를 `main.swift`에 배선하고
/// `TinyTest.summarize()`를 호출한다. 이 파일은 요약·종료를 하지 않는다.
@MainActor
func runSettingsTests() {
    // (a) 저장된 값이 없으면 load는 기본 설정을 돌려준다.
    TinyTest.test("SettingsStore.load returns default when empty") {
        let defaults = UserDefaults(suiteName: "test-\(UUID())")!
        let store = SettingsStore(defaults: defaults)
        TinyTest.equal(store.settings, Settings.default, "empty store returns default")
    }

    // (b) 값을 저장하고 다시 읽으면 변경 사항이 유지된다.
    TinyTest.test("SettingsStore round-trips persisted changes") {
        let defaults = UserDefaults(suiteName: "test-\(UUID())")!
        let store = SettingsStore(defaults: defaults)
        var updated = store.settings
        updated.spotlightEnabled = true
        updated.highlightDiameter = 72
        store.settings = updated

        let reloaded = SettingsStore(defaults: defaults)
        TinyTest.check(reloaded.settings.spotlightEnabled, "spotlightEnabled persisted as true")
        TinyTest.equalApprox(reloaded.settings.highlightDiameter, 72, "highlightDiameter persisted as 72")
    }
}
