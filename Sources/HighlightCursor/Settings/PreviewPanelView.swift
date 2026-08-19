import AppKit
import HighlightCursorCore

/// 설정 창 안에서 하이라이트·스포트라이트를 실제와 동일한 레이어 클래스로
/// 미리 보여주는 작은 패널. 가상 커서를 패널 중앙에 고정해두고, 슬라이더로
/// 조정 중인 크기·색·반경·어둡기를 정적으로 시각화하는 용도다.
///
/// 이 미리보기는 켜짐/꺼짐 여부와 무관하게 항상 두 효과를 보여준다 — 목적이
/// "지금 화면에서 실제로 켜져 있는가"가 아니라 "이 값으로 조정하면 이렇게
/// 보인다"이기 때문이다. 트레일은 정적인 미리보기에서는 보여줄 방법이 없어
/// (움직임이 있어야 잔상이 생긴다) 제외한다.
///
/// 애니메이션·타이머가 전혀 없어 배터리 걱정 없이 항상 떠 있어도 된다.
@MainActor
final class PreviewPanelView: NSView {
    private let panelSize = CGSize(width: 360, height: 140)

    private var highlight: HighlightLayer?
    private var spotlight: SpotlightLayer?

    init(settings: Settings) {
        super.init(frame: NSRect(origin: .zero, size: panelSize))
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.05, alpha: 1).cgColor
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        widthAnchor.constraint(equalToConstant: panelSize.width).isActive = true
        heightAnchor.constraint(equalToConstant: panelSize.height).isActive = true

        rebuildEffects()
        apply(settings)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// 슬라이더 변경 시 호출. 두 효과 레이어에 새 설정을 즉시 반영하고
    /// 패널 중앙에 고정된 위치에 다시 그린다. 켜짐/꺼짐 상태는 무시하고
    /// 항상 표시한다(조정 중인 값을 보여주는 것이 목적).
    func apply(_ settings: Settings) {
        let center = CGPoint(x: panelSize.width / 2, y: panelSize.height / 2)

        highlight?.apply(settings: settings)
        spotlight?.apply(settings: settings, screenSize: panelSize)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        spotlight?.move(to: center)
        highlight?.move(to: center)
        CATransaction.commit()
    }

    // MARK: - Private

    private func rebuildEffects() {
        guard let root = layer else { return }
        highlight = HighlightLayer(settings: Settings.default)
        spotlight = SpotlightLayer(settings: Settings.default, screenSize: panelSize)

        // z-order: 스포트라이트(맨 아래) → 하이라이트(맨 위), 실제 앱과 동일.
        spotlight?.layer.zPosition = -100
        root.insertSublayer(spotlight!.layer, at: 0)
        root.addSublayer(highlight!.layer)
    }
}
