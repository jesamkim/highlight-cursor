import QuartzCore
import HighlightCursorCore

/// 커서를 따라다니는 링(테두리) 형태의 하이라이트 레이어.
/// 원 안은 비우고 테두리만 은은한 글로우로 커서 위치를 강조한다. 위치 갱신은
/// `move(to:)`가 `layer.position`만 바꾸므로 CPU 비용이 최소다.
@MainActor
final class HighlightLayer {
    let layer = CAShapeLayer()
    private var diameter: Double = 50
    /// 테두리 두께(내부 채움 없이 링만 그린다).
    private let lineWidth: CGFloat = 3

    init(settings: Settings) {
        apply(settings: settings)
    }

    /// 지름·색·투명도·글로우를 설정값에서 반영한다. 내부는 채우지 않고 테두리만 그린다.
    func apply(settings: Settings) {
        diameter = settings.highlightDiameter
        let d = CGFloat(diameter)
        layer.frame = CGRect(x: 0, y: 0, width: d, height: d)
        // 테두리가 프레임 밖으로 잘리지 않도록 lineWidth 절반만큼 안쪽으로 원을 그린다.
        let inset = lineWidth / 2
        let ringRect = CGRect(x: inset, y: inset, width: d - lineWidth, height: d - lineWidth)
        layer.path = CGPath(ellipseIn: ringRect, transform: nil)
        // 내부 채움 없음: 테두리(stroke)만 보이게 한다.
        layer.fillColor = nil
        layer.lineWidth = lineWidth
        layer.strokeColor = ColorHex.cgColor(settings.highlightColorHex, alpha: settings.highlightOpacity)
        // 은은한 글로우.
        layer.shadowColor = ColorHex.cgColor(settings.highlightColorHex, alpha: 1.0)
        layer.shadowRadius = 6
        // 글로우 세기도 사용자의 투명도 설정을 반영한다(투명도를 낮추면 글로우도 함께 옅어짐).
        layer.shadowOpacity = Float(settings.highlightOpacity * 2.0)
        layer.shadowOffset = .zero
    }

    /// 레이어 중심을 지정 좌표로 옮긴다(anchorPoint 기본 0.5,0.5 → 중심 정렬).
    func move(to point: CGPoint) {
        layer.position = point
    }
}
