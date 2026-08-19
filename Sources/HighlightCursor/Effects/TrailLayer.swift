import QuartzCore
import HighlightCursorCore

/// 빠른 이동 시 마우스 뒤에 남는 작은 점 잔상들.
/// 각 점은 일회성 `CALayer`로, 추가 즉시 opacity 페이드아웃 애니메이션을 걸어
/// GPU가 소멸을 처리한다. 동시 존재 개수를 `settings.trailMaxCount`로 제한해
/// 무한 누적을 막는다(오래된 점은 즉시 제거).
@MainActor
final class TrailLayer {
    private var dots: [CALayer] = []
    private var maxCount: Int
    private var colorHex: String
    private var opacity: Double

    init(settings: Settings) {
        maxCount = max(0, settings.trailMaxCount)
        colorHex = settings.highlightColorHex
        opacity = settings.highlightOpacity
    }

    /// 최대 개수·색·투명도를 설정값에서 반영한다. 이미 떠 있는 점에는 영향 없음
    /// (다음에 새로 생기는 점부터 반영). 음수 개수는 0으로 정규화해
    /// `removeFirst()`가 빈 배열에서 호출되는 크래시를 막는다.
    func apply(settings: Settings) {
        maxCount = max(0, settings.trailMaxCount)
        colorHex = settings.highlightColorHex
        opacity = settings.highlightOpacity
    }

    /// 지정 좌표에 잔상 점 하나를 남기고 0.5초에 걸쳐 페이드아웃시킨다.
    /// `below`가 주어지면 그 레이어(보통 하이라이트) 바로 아래에 삽입해
    /// 트레일이 하이라이트를 가리지 않게 한다. 없으면 맨 위에 추가한다.
    func addPoint(_ point: CGPoint, on root: CALayer, below: CALayer? = nil) {
        let size: CGFloat = 12
        let dot = CALayer()
        dot.frame = CGRect(x: 0, y: 0, width: size, height: size)
        dot.cornerRadius = size / 2
        dot.position = point
        dot.backgroundColor = ColorHex.cgColor(colorHex, alpha: opacity)
        if let below, below.superlayer === root, let idx = root.sublayers?.firstIndex(where: { $0 === below }) {
            root.insertSublayer(dot, at: UInt32(idx))
        } else {
            root.addSublayer(dot)
        }
        dots.append(dot)

        // 개수 상한 초과 시 가장 오래된 점부터 즉시 제거(무한 누적 방지).
        // dots.isEmpty 가드는 이중 방어(apply의 정규화가 이미 음수를 막지만,
        // maxCount가 0인 정상 케이스에서도 안전하게 종료되도록 한다).
        while dots.count > maxCount, !dots.isEmpty {
            dots.removeFirst().removeFromSuperlayer()
        }

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = opacity
        fade.toValue = 0.0
        fade.duration = 0.5

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self, weak dot] in
            guard let dot else { return }
            dot.removeFromSuperlayer()
            self?.dots.removeAll { $0 === dot }
        }
        dot.opacity = 0
        dot.add(fade, forKey: "trail")
        CATransaction.commit()
    }

    /// 화면 전환 등으로 남아 있는 모든 점을 즉시 제거한다(트레일 끔/재활성화 시 사용).
    func clear() {
        dots.forEach { $0.removeFromSuperlayer() }
        dots.removeAll()
    }
}
