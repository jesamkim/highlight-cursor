import AppKit
import HighlightCursorCore

/// 설정 창 안에서 하이라이트·스포트라이트·트레일을 실제와 동일한 레이어 클래스로
/// 미리 보여주는 작은 패널. 실제 마우스 이벤트가 없으므로 가상 커서를 좌우로
/// 왕복시켜 트레일 잔상과 스포트라이트 이동을 함께 확인할 수 있게 한다.
///
/// 실제 오버레이(`EffectCoordinator`)와 별개의 독립된 레이어 인스턴스를 쓴다 —
/// 화면 전체 오버레이에 영향을 주지 않고, 패널이 닫히면 타이머를 반드시 멈춰
/// 배터리를 쓰지 않는다.
@MainActor
final class PreviewPanelView: NSView {
    private let panelSize = CGSize(width: 360, height: 140)

    private var highlight: HighlightLayer?
    private var spotlight: SpotlightLayer?
    private var trail: TrailLayer?

    private var settings: Settings
    private var timer: Timer?
    private var t: Double = 0   // 0~1 왕복 위상

    init(settings: Settings) {
        self.settings = settings
        super.init(frame: NSRect(origin: .zero, size: panelSize))
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.05, alpha: 1).cgColor
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        widthAnchor.constraint(equalToConstant: panelSize.width).isActive = true
        heightAnchor.constraint(equalToConstant: panelSize.height).isActive = true

        rebuildEffects()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// 슬라이더 변경 시 호출. 살아있는 효과 레이어에 새 설정을 즉시 반영한다.
    func apply(_ settings: Settings) {
        self.settings = settings
        highlight?.apply(settings: settings)
        spotlight?.apply(settings: settings, screenSize: panelSize)
        trail?.apply(settings: settings)
    }

    /// 패널이 화면에 보이는 동안만 가상 커서 애니메이션을 돌린다. 창이 닫히면
    /// 반드시 `stopAnimating()`을 호출해 타이머가 배경에서 계속 돌지 않게 한다.
    func startAnimating() {
        stopAnimating()
        // 60fps 폴링이 아니라 미리보기 전용 저비용 타이머(1/30초 간격)로,
        // 창이 열려 있을 때만 동작하고 닫히면 즉시 멈춘다.
        // NSSlider 드래그는 별도의 이벤트 트래킹 run-loop 모드로 도는데,
        // 기본 모드로만 등록하면 슬라이더를 끄는 동안 타이머가 멈춰 라이브
        // 미리보기가 정지된다. .common 모드에 추가해 드래그 중에도 계속 돌게 한다.
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.step() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stopAnimating() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Private

    private func rebuildEffects() {
        guard let root = layer else { return }
        highlight = HighlightLayer(settings: settings)
        spotlight = SpotlightLayer(settings: settings, screenSize: panelSize)
        trail = TrailLayer(settings: settings)

        // z-order: 스포트라이트(맨 아래) → 트레일 → 하이라이트(맨 위), 실제 앱과 동일.
        spotlight?.layer.zPosition = -100
        root.insertSublayer(spotlight!.layer, at: 0)
        root.addSublayer(highlight!.layer)
    }

    /// 가상 커서를 패널 안에서 좌우로 왕복시키고, 각 효과 레이어에 위치를 반영한다.
    private func step() {
        guard let root = layer else { return }
        t += 0.02
        if t > 1 { t = 0 }
        // ease-in-out 삼각파: 0→1→0 왕복.
        let phase = t < 0.5 ? t * 2 : (1 - t) * 2
        let margin: CGFloat = 60
        let x = margin + CGFloat(phase) * (panelSize.width - margin * 2)
        let point = CGPoint(x: x, y: panelSize.height / 2)

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // 꺼진 효과는 레이어를 숨겨서 미리보기가 실제 상태(끔)를 정확히 반영하게 한다.
        // 기본값(스포트라이트 꺼짐)에서 패널이 항상 어둡게 보이는 등의 오해를 막는다.
        spotlight?.layer.isHidden = !settings.spotlightEnabled
        highlight?.layer.isHidden = !settings.highlightEnabled

        if settings.spotlightEnabled {
            spotlight?.move(to: point)
        }
        if settings.trailEnabled {
            trail?.addPoint(point, on: root, below: highlight?.layer)
        }
        if settings.highlightEnabled {
            highlight?.move(to: point)
        }

        CATransaction.commit()
    }
}
