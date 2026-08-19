import QuartzCore
import HighlightCursorCore

/// 커서를 따라다니는 반투명 원형 하이라이트 레이어.
/// 은은한 글로우(shadow)로 커서 위치를 강조한다. 위치 갱신은 `move(to:)`가
/// `layer.position`만 바꾸므로 CPU 비용이 최소다.
@MainActor
final class HighlightLayer {
    let layer = CAShapeLayer()
    private var diameter: Double = 50

    init(settings: Settings) {
        apply(settings: settings)
    }

    /// 지름·색·투명도·글로우를 설정값에서 반영한다.
    func apply(settings: Settings) {
        diameter = settings.highlightDiameter
        let d = diameter
        layer.frame = CGRect(x: 0, y: 0, width: d, height: d)
        layer.path = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: d, height: d), transform: nil)
        layer.fillColor = ColorHex.cgColor(settings.highlightColorHex, alpha: settings.highlightOpacity)
        layer.shadowColor = ColorHex.cgColor(settings.highlightColorHex, alpha: 1.0)
        layer.shadowRadius = 8
        // 글로우 세기도 사용자의 투명도 설정을 반영한다(투명도를 낮추면 글로우도 함께 옅어짐).
        layer.shadowOpacity = Float(settings.highlightOpacity * 2.0)
        layer.shadowOffset = .zero
    }

    /// 레이어 중심을 지정 좌표로 옮긴다(anchorPoint 기본 0.5,0.5 → 중심 정렬).
    func move(to point: CGPoint) {
        layer.position = point
    }
}
