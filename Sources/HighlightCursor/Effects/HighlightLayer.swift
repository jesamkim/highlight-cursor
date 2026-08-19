import QuartzCore
import HighlightCursorCore

/// 커서를 따라다니는 링(테두리) 형태의 하이라이트 레이어.
/// 원 안은 비우고 테두리만 은은한 글로우로 커서 위치를 강조한다. 위치 갱신은
/// `move(to:)`가 `layer.position`만 바꾸므로 CPU 비용이 최소다.
@MainActor
final class HighlightLayer {
    let layer = CAShapeLayer()
    private var diameter: Double = 50

    /// 지름에 비례해 테두리 두께를 계산한다(6% 비율, 2~8px 사이로 제한).
    /// 지름이 커질수록 링이 얇아 보이지 않도록 두께도 함께 커지되, 너무 얇거나
    /// 뚱뚱해지지 않게 상하한을 둔다. (기본 지름 50px → 두께 3px, 기존과 동일)
    private static func lineWidth(forDiameter diameter: Double) -> CGFloat {
        let proportional = diameter * 0.06
        return CGFloat(min(max(proportional, 2.0), 8.0))
    }

    init(settings: Settings) {
        apply(settings: settings)
    }

    /// 지름·색·투명도·글로우를 설정값에서 반영한다. 내부는 채우지 않고 테두리만 그린다.
    func apply(settings: Settings) {
        diameter = settings.highlightDiameter
        let d = CGFloat(diameter)
        let lineWidth = Self.lineWidth(forDiameter: diameter)
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

        // 은은한 펄스 애니메이션을 (재)설치한다. apply가 다시 불려도 유지되도록 여기서 건다.
        installPulse(baseGlow: settings.highlightOpacity * 2.0)
    }

    /// 링이 천천히 커졌다 작아지는 스케일 펄스 + 글로우 맥동을 무한 반복으로 건다.
    /// 전부 Core Animation(GPU) 프로퍼티라 애니메이션이 도는 동안 CPU 부담은 거의 없다.
    /// `transform.scale`을 쓰므로 `move(to:)`의 position 갱신과 독립적으로 동작한다.
    private func installPulse(baseGlow: Double) {
        let period: CFTimeInterval = 1.6

        // 스케일: 1.0 → 1.12 → 1.0 (은은하게)
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1.0
        scale.toValue = 1.12

        // 글로우 맥동: 기본 세기의 0.6배 ~ 1.2배 사이를 오간다(과하지 않게).
        let glow = CABasicAnimation(keyPath: "shadowOpacity")
        glow.fromValue = Float(baseGlow * 0.6)
        glow.toValue = Float(min(baseGlow * 1.2, 1.0))

        let group = CAAnimationGroup()
        group.animations = [scale, glow]
        group.duration = period
        group.autoreverses = true                 // 커졌다 다시 작아지도록
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        group.isRemovedOnCompletion = false

        layer.removeAnimation(forKey: "pulse")
        layer.add(group, forKey: "pulse")
    }

    /// 레이어 중심을 지정 좌표로 옮긴다(anchorPoint 기본 0.5,0.5 → 중심 정렬).
    func move(to point: CGPoint) {
        layer.position = point
    }
}
