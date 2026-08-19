import QuartzCore
import HighlightCursorCore

/// 클릭 위치에 일회성 링 물결을 생성한다.
/// 좌클릭은 청록(#22D3EE), 우클릭은 주황(#FF8800).
/// 0.4초간 scale 0.2→1.4 + opacity 0.8→0 애니메이션 후 자동 제거된다.
@MainActor
final class ClickEffectLayer {
    func emit(at point: CGPoint, kind: ClickKind, on root: CALayer) {
        let size: CGFloat = 40
        let ring = CAShapeLayer()
        ring.frame = CGRect(x: 0, y: 0, width: size, height: size)
        ring.position = point
        ring.path = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: size, height: size), transform: nil)
        ring.fillColor = nil
        ring.lineWidth = 3
        ring.strokeColor = kind == .left
            ? ColorHex.cgColor("#22D3EE", alpha: 0.9)
            : ColorHex.cgColor("#FF8800", alpha: 0.9)

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.2
        scale.toValue = 1.4

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.8
        fade.toValue = 0.0

        let group = CAAnimationGroup()
        group.animations = [scale, fade]
        group.duration = 0.4
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards

        CATransaction.begin()
        CATransaction.setCompletionBlock { ring.removeFromSuperlayer() }
        ring.opacity = 0   // 애니메이션 종료 후 보이지 않도록 모델 값을 0으로 설정
        root.addSublayer(ring)
        ring.add(group, forKey: "click")
        CATransaction.commit()
    }
}
