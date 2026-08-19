import CoreGraphics
import HighlightCursorCore

/// 좌표 변환 테스트. 부모가 `main.swift`에서 이 함수를 러너에 배선한다.
/// (여기서는 `TinyTest.summarize()`를 호출하지 않는다.)
@MainActor
func runCoordinateTests() {
    TinyTest.test("CoordinateConverter/originScreen") {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let p = CoordinateConverter.toLayerPoint(
            globalPoint: CGPoint(x: 100, y: 200), in: screen)
        TinyTest.equal(p, CGPoint(x: 100, y: 200), "origin screen")
    }

    TinyTest.test("CoordinateConverter/offsetScreen") {
        let screen = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
        let p = CoordinateConverter.toLayerPoint(
            globalPoint: CGPoint(x: 1500, y: 300), in: screen)
        TinyTest.equal(p, CGPoint(x: 60, y: 300), "offset screen")
    }
}
