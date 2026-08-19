import Foundation
import HighlightCursorCore

/// Task 15: 클릭 이펙트 스타일 설정의 단위 테스트.
/// 핵심은 하위호환 디코딩 — 기존에 저장된 JSON에는 `clickEffectStyle` 키가 없으므로,
/// 그 키가 빠진 JSON을 디코딩해도 실패하지 않고 기본값 `.ripple`이 채워져야 한다.
/// 부모(테스트 러너)가 이 함수를 main.swift에 배선하고 TinyTest.summarize()를 호출한다.
@MainActor
func runClickStyleTests() {
    // (a) 기본값은 ripple이다.
    TinyTest.test("Settings default clickEffectStyle is ripple") {
        TinyTest.equal(Settings.default.clickEffectStyle, .ripple, "default style")
    }

    // (b) clickEffectStyle 키가 없는 예전 JSON을 디코딩하면 ripple로 채워진다(하위호환).
    TinyTest.test("decoding legacy JSON without clickEffectStyle yields ripple") {
        let legacyJSON = """
        {
          "highlightEnabled": true,
          "highlightDiameter": 50,
          "highlightColorHex": "#FFCC00",
          "highlightOpacity": 0.3,
          "clickEffectEnabled": true,
          "spotlightEnabled": false,
          "spotlightRadius": 150,
          "spotlightDimming": 0.5,
          "trailEnabled": false,
          "trailMaxCount": 8
        }
        """
        let data = Data(legacyJSON.utf8)
        do {
            let decoded = try JSONDecoder().decode(Settings.self, from: data)
            TinyTest.equal(decoded.clickEffectStyle, .ripple, "missing key defaults to ripple")
            // 나머지 필드도 정상 디코딩됐는지 함께 확인한다.
            TinyTest.equal(decoded.trailMaxCount, 8, "other fields still decode")
            TinyTest.check(decoded.clickEffectEnabled, "clickEffectEnabled decoded")
        } catch {
            TinyTest.check(false, "legacy JSON should decode without throwing: \(error)")
        }
    }

    // (c) clickEffectStyle 키가 있으면 그 값을 존중한다.
    TinyTest.test("decoding JSON with explicit clickEffectStyle round-trips") {
        var s = Settings.default
        s.clickEffectStyle = .sakura
        do {
            let data = try JSONEncoder().encode(s)
            let decoded = try JSONDecoder().decode(Settings.self, from: data)
            TinyTest.equal(decoded.clickEffectStyle, .sakura, "explicit style round-trips")
        } catch {
            TinyTest.check(false, "encode/decode should not throw: \(error)")
        }
    }

    // (d) 모든 스타일 케이스가 rawValue로 왕복된다(메뉴 representedObject 경로 검증).
    TinyTest.test("all ClickEffectStyle cases round-trip via rawValue") {
        for style in ClickEffectStyle.allCases {
            TinyTest.equal(ClickEffectStyle(rawValue: style.rawValue), style, "rawValue round-trip \(style)")
        }
    }
}
