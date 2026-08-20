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
    private static let ghostCount = 12

    // MARK: - 진입점

    /// 동시에 살아있는 클릭 이펙트 파티클 레이어 수의 상한.
    /// 연타(오토클리커 포함) 시 레이어가 무한정 쌓여 GPU 애니메이션이 누적되는 것을 막는다.
    /// 예산이 소진된 상태에서 들어온 클릭은 조용히 무시(coalesce)한다. 각 파티클은
    /// 0.45~0.9초 뒤 완료 콜백에서 카운트를 되돌린다.
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
        case .ghostRain:   requested = ghostCount
        }
        guard activeParticleCount + requested <= maxConcurrentParticles else { return }

        switch style {
        case .ripple:      emitRipple(at: point, kind: kind, on: root)
        case .sakura:      emitSakura(at: point, on: root)
        case .energyBurst: emitEnergyBurst(at: point, kind: kind, on: root)
        case .sparkle:     emitSparkle(at: point, on: root)
        case .ghostRain:   emitGhostRain(at: point, on: root)
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

    // MARK: - ghostRain (작은 Kiro 유령들이 커서 아래로 우르르 쏟아짐)

    /// 클릭 지점에서 작은 유령들이 좌우 양쪽으로 퍼지며 포물선을 그린다. 각자 살짝 위로
    /// 솟았다가 중력을 받아 아래로 떨어진다. 이동 경로는 2차 베지에로 만들어서(등속 수평 +
    /// 등가속 수직 운동과 수학적으로 동일) 실제 투사체처럼 보인다. 마리마다 좌우 거리와
    /// 솟는 높이, 낙하 거리, 지속시간, 크기를 다르게 줘서 다이나믹하게 흩어진다.
    /// 유령 모양은 KiroCrew 응답 대기에 쓰이는 Lucide `ghost` 아이콘 path를 그대로 쓴다.
    static func emitGhostRain(at point: CGPoint, on root: CALayer) {
        for i in 0..<ghostCount {
            let ghost = makeGhost()
            ghost.position = point

            // 좌우로 퍼지는 포물선 투사체 운동.
            // 유령을 좌/우 양쪽으로 갈라 보내고(부채꼴), 각자 살짝 위로 솟았다가
            // 중력을 받아 아래로 떨어진다.
            // 좌우 분배: 짝수는 오른쪽, 홀수는 왼쪽. 안쪽부터 바깥쪽으로 배치한다.
            let side: CGFloat = (i % 2 == 0) ? 1 : -1
            let rank = CGFloat(i / 2)                                  // 0,0,1,1,2,2...
            let ranks = CGFloat(max((ghostCount + 1) / 2, 1))
            // 가운데(거의 수직 낙하)부터 바깥쪽까지 고르게 채운다.
            let lateral = (rank / ranks * 105) * side                   // 좌우 0~105px
                + CGFloat.random(in: -9...9)
            // 제어점을 시작점보다 얼마나 위에 둘지(정점 높이 자체는 아니다. 아래 설명 참고).
            let lift = CGFloat.random(in: 26...44)
            let drop = CGFloat.random(in: 105...155)                   // 아래로 낙하

            // 2차 베지에로 포물선을 그린다. 제어점을 시작점보다 lift*2 위에 두면
            // 곡선은 살짝 솟았다가 종점까지 가속하며 떨어진다.
            // 실제 정점 높이는 4*lift^2 / (drop + 4*lift)이므로 현재 범위에서 약 13~23px이다.
            // (등속 수평 + 등가속 수직 운동은 수학적으로 2차 베지에와 동일하다.)
            let arc = CGMutablePath()
            arc.move(to: point)
            arc.addQuadCurve(
                to: CGPoint(x: point.x + lateral, y: point.y - drop),
                control: CGPoint(x: point.x + lateral * 0.5, y: point.y + lift * 2)
            )

            let move = CAKeyframeAnimation(keyPath: "position")
            move.path = arc
            move.calculationMode = .linear
            // 시간에 대해 선형으로 경로를 따라가면 베지에 자체가 중력 가속을 만든다.
            move.timingFunction = CAMediaTimingFunction(name: .linear)

            // 떨어지는 동안 진행 방향으로 완만하게 기운다(퍼지는 쪽으로 눕는 느낌).
            let sway = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            let tilt = CGFloat.random(in: 0.35...0.7) * side
            sway.values = [0, tilt * 0.4, tilt]
            sway.keyTimes = [0.0, 0.4, 1.0]
            sway.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            // 크기: 톡 튀어나오듯 살짝 오버슈트한 뒤 제 크기, 끝에 줄며 사라짐.
            let base = CGFloat.random(in: 0.5...0.85)
            let scale = CAKeyframeAnimation(keyPath: "transform.scale")
            scale.values = [0.2, base * 1.06, base, base * 0.7]
            scale.keyTimes = [0.0, 0.18, 0.6, 1.0]

            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0.0, 0.98, 0.9, 0.0]
            fade.keyTimes = [0.0, 0.12, 0.65, 1.0]

            let group = CAAnimationGroup()
            group.animations = [move, sway, scale, fade]
            group.duration = CFTimeInterval.random(in: 0.75...1.15)   // 지속시간 편차
            group.isRemovedOnCompletion = false
            group.fillMode = .forwards
            // 반짝임처럼 클릭 순간 거의 동시에 퍼지되, 아주 짧은 시차만 준다.
            group.beginTime = CACurrentMediaTime() + Double(i) * 0.012

            addOneShot(ghost, animation: group, key: "ghost", on: root)
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

    /// 작은 Kiro 유령(흰색). KiroCrew 응답 대기 UI에 쓰이는 Lucide `ghost` 아이콘의
    /// 24x24 뷰박스 path를 그대로 사용한다(몸통 + 눈 두 개). 몸통은 흰색으로 채우고
    /// 눈은 어두운 점으로 찍어 그 유령과 같은 인상을 만든다.
    private static func makeGhost() -> CAShapeLayer {
        let box: CGFloat = 24
        let layer = CAShapeLayer()
        layer.bounds = CGRect(x: 0, y: 0, width: box, height: box)

        // Lucide ghost 몸통 path (24x24 뷰박스). SVG는 좌상단 원점이므로 y를 뒤집어
        // bottom-left 원점인 CALayer 좌표계에 맞춘다.
        // 형태: 반지름 8 반원 머리(위) + 수직 몸통 + 물결 밑단 4개.
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: box - y) }

        let body = CGMutablePath()
        // 왼쪽 어깨(4,10)에서 시작.
        body.move(to: p(4, 10))
        // 머리: 중심(12,10) 반지름 8의 반원을 왼쪽 어깨에서 오른쪽 어깨로.
        // y를 뒤집은 좌표계이므로 각도 진행 방향도 뒤집혀 clockwise=true가 위쪽 반원이 된다.
        body.addArc(center: p(12, 10), radius: 8,
                    startAngle: .pi, endAngle: 0, clockwise: true)
        // 오른쪽 몸통을 아래로 내린 뒤(20,22) 물결 밑단을 왼쪽으로 그어간다.
        body.addLine(to: p(20, 22))
        body.addLine(to: p(17, 19))
        body.addLine(to: p(14.5, 21.5))
        body.addLine(to: p(12, 19))
        body.addLine(to: p(9.5, 21.5))
        body.addLine(to: p(7, 19))
        body.addLine(to: p(4, 22))
        body.closeSubpath()   // 왼쪽 몸통을 따라 시작점으로

        // 눈 두 개(Lucide의 M9 10 / M15 10 점). evenOdd로 몸통에서 파낸다.
        let eyeR: CGFloat = 1.15
        let leftEye = p(9, 10), rightEye = p(15, 10)
        body.addEllipse(in: CGRect(x: leftEye.x - eyeR, y: leftEye.y - eyeR,
                                   width: eyeR * 2, height: eyeR * 2))
        body.addEllipse(in: CGRect(x: rightEye.x - eyeR, y: rightEye.y - eyeR,
                                   width: eyeR * 2, height: eyeR * 2))

        layer.path = body
        layer.fillColor = ColorHex.cgColor("#FFFFFF", alpha: 0.95)
        layer.fillRule = .evenOdd   // 눈 구멍이 몸통에서 파이도록
        // 은은한 그림자로 어두운 배경에서도 유령이 떠 보이게.
        layer.shadowColor = CGColor(gray: 0, alpha: 1)
        layer.shadowRadius = 2
        layer.shadowOpacity = 0.35
        layer.shadowOffset = CGSize(width: 0, height: -1)
        return layer
    }
}
