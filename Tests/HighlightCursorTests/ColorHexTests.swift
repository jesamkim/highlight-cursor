import CoreGraphics
import HighlightCursorCore

/// ColorHex 파싱 테스트. 부모가 `main.swift`에서 이 함수를 러너에 배선한다.
/// (여기서는 `TinyTest.summarize()`를 호출하지 않는다.)
@MainActor
func runColorHexTests() {
    TinyTest.test("ColorHex/parsesValidHex") {
        let c = ColorHex.cgColor("#FF0000", alpha: 1.0)
        let comps = c.components ?? []
        TinyTest.check(comps.count >= 3, "components present")
        if comps.count >= 3 {
            TinyTest.equalApprox(comps[0], 1.0, "red")
            TinyTest.equalApprox(comps[1], 0.0, "green")
            TinyTest.equalApprox(comps[2], 0.0, "blue")
        }
    }

    TinyTest.test("ColorHex/fallsBackOnInvalid") {
        let c = ColorHex.cgColor("nope", alpha: 1.0)
        TinyTest.check(c.components != nil, "fallback color has components")
    }
}
