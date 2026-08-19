import QuartzCore
import HighlightCursorCore

/// 클릭 이펙트 스타일별 렌더러. 각 스타일은 클릭 지점에 일회성 레이어(들)를 만들고
/// 전부 Core Animation(GPU)으로 애니메이션한 뒤 완료 시 `removeFromSuperlayer`로 정리한다.
/// 파티클 개수는 상수로 상한을 두어 클릭을 연타해도 부담이 커지지 않게 한다.
///
/// 모든 함수는 메인 스레드(오버레이 레이어 트리)에서만 호출되므로 `@MainActor`로 격리한다.
@MainActor
enum ClickEffectStyleRenderer {

    // MARK: - 색상

    private static func primaryColor(_ kind: ClickKind, alpha: Double) -> CGColor {
        kind == .left
            ? ColorHex.cgColor("#22D3EE", alpha: alpha)   // 청록(좌)
            : ColorHex.cgColor("#FF8800", alpha: alpha)   // 주황(우)
    }

    private static let sakuraPink = "#FFB7C5"
    private static let sparkleGold = "#FFD700"

    // MARK: - 파티클 개수 상한(리소스 보호)

    private static let sakuraPetals = 6
    private static let burstRays = 8
    private static let sparkleStars = 8

    // MARK: - 진입점

    /// 동시에 살아있는 클릭 이펙트 파티클 레이어 수의 상한.
    /// 연타(오토클리커 포함) 시 레이어가 무한정 쌓여 GPU 애니메이션이 누적되는 것을 막는다.
    /// 예산이 소진된 상태에서 들어온 클릭은 조용히 무시(coalesce)한다. 각 파티클은
    /// 0.45~0.6초 뒤 완료 콜백에서 카운트를 되돌린다.
    private static let maxConcurrentParticles = 48
    private static var activeParticleCount = 0

    static func emit(style: ClickEffectStyle, at point: CGPoint, kind: ClickKind, on root: CALayer) {
        // 이번 방출이 요구하는 파티클 수. 예산을 넘기면 이 클릭은 건너뛴다.
        let requested: Int
        switch style {
        case .ripple:      requested = 1
        case .sakura:      requested = sakuraPetals
        case .energyBurst: requested = burstRays + 1   // 광선 + 중앙 링
        case .sparkle:     requested = sparkleStars
        }
        guard activeParticleCount + requested <= maxConcurrentParticles else { return }

        switch style {
        case .ripple:      emitRipple(at: point, kind: kind, on: root)
        case .sakura:      emitSakura(at: point, on: root)
        case .energyBurst: emitEnergyBurst(at: point, kind: kind, on: root)
        case .sparkle:     emitSparkle(at: point, on: root)
        }
    }

    // MARK: - ripple (기본형: 링 하나가 퍼지며 사라짐)

    static func emitRipple(at point: CGPoint, kind: ClickKind, on root: CALayer) {
        let size: CGFloat = 40
        let ring = CAShapeLayer()
        ring.frame = CGRect(x: 0, y: 0, width: size, height: size)
        ring.position = point
        ring.path = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: size, height: size), transform: nil)
        ring.fillColor = nil
        ring.lineWidth = 3
        ring.strokeColor = primaryColor(kind, alpha: 0.9)

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

        addOneShot(ring, animation: group, key: "ripple", on: root)
    }

    // MARK: - sakura (분홍 벚꽃잎이 회전·부유하며 퍼짐)

    static func emitSakura(at point: CGPoint, on root: CALayer) {
        for i in 0..<sakuraPetals {
            let petal = makePetal(color: ColorHex.cgColor(sakuraPink, alpha: 0.9))
            petal.position = point

            let angle = (CGFloat(i) / CGFloat(sakuraPetals)) * 2 * .pi
            let distance: CGFloat = 34
            let end = CGPoint(x: point.x + cos(angle) * distance,
                              y: point.y + sin(angle) * distance)

            let move = CABasicAnimation(keyPath: "position")
            move.fromValue = NSValue(point: point)
            move.toValue = NSValue(point: end)

            let spin = CABasicAnimation(keyPath: "transform.rotation.z")
            spin.fromValue = 0
            spin.toValue = (i % 2 == 0 ? 1 : -1) * CGFloat.pi   // 잎마다 회전 방향 교차

            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.95
            fade.toValue = 0.0

            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 0.5
            scale.toValue = 1.0

            let group = CAAnimationGroup()
            group.animations = [move, spin, fade, scale]
            group.duration = 0.6
            group.timingFunction = CAMediaTimingFunction(name: .easeOut)
            group.isRemovedOnCompletion = false
            group.fillMode = .forwards

            addOneShot(petal, animation: group, key: "sakura", on: root)
        }
    }

    // MARK: - energyBurst (중앙 링 확산 + 방사형 광선)

    static func emitEnergyBurst(at point: CGPoint, kind: ClickKind, on root: CALayer) {
        // 중앙 링
        let ringSize: CGFloat = 30
        let ring = CAShapeLayer()
        ring.frame = CGRect(x: 0, y: 0, width: ringSize, height: ringSize)
        ring.position = point
        ring.path = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: ringSize, height: ringSize), transform: nil)
        ring.fillColor = nil
        ring.lineWidth = 2.5
        ring.strokeColor = primaryColor(kind, alpha: 0.95)

        let ringScale = CABasicAnimation(keyPath: "transform.scale")
        ringScale.fromValue = 0.3
        ringScale.toValue = 1.8
        let ringFade = CABasicAnimation(keyPath: "opacity")
        ringFade.fromValue = 0.9
        ringFade.toValue = 0.0
        let ringGroup = CAAnimationGroup()
        ringGroup.animations = [ringScale, ringFade]
        ringGroup.duration = 0.5
        ringGroup.timingFunction = CAMediaTimingFunction(name: .easeOut)
        ringGroup.isRemovedOnCompletion = false
        ringGroup.fillMode = .forwards
        addOneShot(ring, animation: ringGroup, key: "burstRing", on: root)

        // 방사형 광선: 팍 뻗었다가 수축(집중선)
        let rayLength: CGFloat = 26
        for i in 0..<burstRays {
            let angle = (CGFloat(i) / CGFloat(burstRays)) * 2 * .pi
            let ray = CALayer()
            ray.bounds = CGRect(x: 0, y: 0, width: 3, height: rayLength)
            ray.position = point
            ray.anchorPoint = CGPoint(x: 0.5, y: 0)   // 안쪽 끝을 클릭 지점에 고정
            ray.backgroundColor = primaryColor(kind, alpha: 0.9)
            ray.cornerRadius = 1.5
            ray.transform = CATransform3DMakeRotation(angle, 0, 0, 1)

            let stretch = CAKeyframeAnimation(keyPath: "transform.scale.y")
            stretch.values = [0.2, 1.0, 0.0]          // 뻗음 → 수축
            stretch.keyTimes = [0.0, 0.5, 1.0]
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.9
            fade.toValue = 0.0

            let group = CAAnimationGroup()
            group.animations = [stretch, fade]
            group.duration = 0.45
            group.timingFunction = CAMediaTimingFunction(name: .easeOut)
            group.isRemovedOnCompletion = false
            group.fillMode = .forwards
            addOneShot(ray, animation: group, key: "burstRay", on: root)
        }
    }

    // MARK: - sparkle (작은 별들이 사방으로 튀며 반짝임)

    static func emitSparkle(at point: CGPoint, on root: CALayer) {
        for i in 0..<sparkleStars {
            let star = makeStar(color: ColorHex.cgColor(sparkleGold, alpha: 0.95))
            star.position = point

            let angle = (CGFloat(i) / CGFloat(sparkleStars)) * 2 * .pi + 0.2
            let distance: CGFloat = 30
            let end = CGPoint(x: point.x + cos(angle) * distance,
                              y: point.y + sin(angle) * distance)

            let move = CABasicAnimation(keyPath: "position")
            move.fromValue = NSValue(point: point)
            move.toValue = NSValue(point: end)

            // 반짝임: 커졌다 작아지는 스케일 키프레임
            let twinkle = CAKeyframeAnimation(keyPath: "transform.scale")
            twinkle.values = [0.2, 1.2, 0.6, 0.0]
            twinkle.keyTimes = [0.0, 0.4, 0.7, 1.0]

            let spin = CABasicAnimation(keyPath: "transform.rotation.z")
            spin.fromValue = 0
            spin.toValue = CGFloat.pi

            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.95
            fade.toValue = 0.0

            let group = CAAnimationGroup()
            group.animations = [move, twinkle, spin, fade]
            group.duration = 0.5
            group.timingFunction = CAMediaTimingFunction(name: .easeOut)
            group.isRemovedOnCompletion = false
            group.fillMode = .forwards

            addOneShot(star, animation: group, key: "sparkle", on: root)
        }
    }

    // MARK: - 공통 헬퍼

    /// 레이어를 루트에 붙이고 애니메이션을 걸며, 완료 시 자동으로 제거한다.
    /// 살아있는 파티클 수를 세어 완료 시 되돌려, 상위 `emit`의 동시 상한이 유효하게 한다.
    private static func addOneShot(_ layer: CALayer, animation: CAAnimation, key: String, on root: CALayer) {
        activeParticleCount += 1
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            layer.removeFromSuperlayer()
            activeParticleCount = max(0, activeParticleCount - 1)
        }
        layer.opacity = 0   // 애니메이션 종료 후 잔상이 남지 않도록 모델 값을 0으로
        root.addSublayer(layer)
        layer.add(animation, forKey: key)
        CATransaction.commit()
    }

    /// 작은 벚꽃잎 모양의 CAShapeLayer. 물방울/타원형 잎을 베지어로 그린다.
    private static func makePetal(color: CGColor) -> CAShapeLayer {
        let w: CGFloat = 14, h: CGFloat = 18
        let layer = CAShapeLayer()
        layer.bounds = CGRect(x: 0, y: 0, width: w, height: h)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: w / 2, y: 0))
        path.addCurve(to: CGPoint(x: w / 2, y: h),
                      control1: CGPoint(x: w, y: h * 0.3),
                      control2: CGPoint(x: w * 0.75, y: h))
        path.addCurve(to: CGPoint(x: w / 2, y: 0),
                      control1: CGPoint(x: w * 0.25, y: h),
                      control2: CGPoint(x: 0, y: h * 0.3))
        layer.path = path
        layer.fillColor = color
        return layer
    }

    /// 작은 5각 별 모양의 CAShapeLayer.
    private static func makeStar(color: CGColor) -> CAShapeLayer {
        let size: CGFloat = 16
        let layer = CAShapeLayer()
        layer.bounds = CGRect(x: 0, y: 0, width: size, height: size)
        let center = CGPoint(x: size / 2, y: size / 2)
        let outer = size / 2
        let inner = outer * 0.42
        let path = CGMutablePath()
        let points = 5
        for i in 0..<(points * 2) {
            let r = (i % 2 == 0) ? outer : inner
            let angle = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
            let p = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        layer.path = path
        layer.fillColor = color
        return layer
    }
}
