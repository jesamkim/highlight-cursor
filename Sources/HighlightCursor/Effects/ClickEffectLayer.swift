import QuartzCore
import HighlightCursorCore

/// 클릭 위치에 일회성 이펙트를 생성한다.
/// 스타일 프리셋(ripple/sakura/energyBurst/sparkle)에 따라 렌더러로 분기하며,
/// 모든 레이어는 애니메이션 종료 시 자동 제거되어 누적되지 않는다.
/// ripple은 좌클릭 청록(#22D3EE)/우클릭 주황(#FF8800)으로 색을 구분한다.
@MainActor
final class ClickEffectLayer {
    func emit(at point: CGPoint, kind: ClickKind, style: ClickEffectStyle, on root: CALayer) {
        ClickEffectStyleRenderer.emit(style: style, at: point, kind: kind, on: root)
    }
}
