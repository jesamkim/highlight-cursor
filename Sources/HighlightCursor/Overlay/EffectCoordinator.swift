import AppKit
import HighlightCursorCore

/// 마우스 이동/클릭을 받아 커서가 속한 화면의 루트 레이어를 찾고,
/// 레이어 로컬 좌표로 변환해 각 효과 레이어에 브로드캐스트한다.
/// 위치 갱신은 `CATransaction.setDisableActions(true)`로 암묵적 애니메이션을 끈다.
@MainActor
final class EffectCoordinator {
    private let controller: OverlayWindowController
    private let store: SettingsStore

    // Task 6: 커서 하이라이트. 현재 붙어 있는 루트 레이어를 추적해
    // 커서가 다른 화면으로 넘어가면 제거 후 새 루트에 다시 붙인다.
    private var highlight: HighlightLayer?
    private var highlightRoot: CALayer?

    init(controller: OverlayWindowController, store: SettingsStore) {
        self.controller = controller
        self.store = store
    }

    func handleMove(global: CGPoint) {
        guard let (layer, frame) = controller.rootLayer(forGlobal: global) else { return }
        let point = CoordinateConverter.toLayerPoint(globalPoint: global, in: frame)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        broadcastMove(point: point, root: layer)
        CATransaction.commit()
    }

    func handleClick(global: CGPoint, kind: ClickKind) {
        guard let (layer, frame) = controller.rootLayer(forGlobal: global) else { return }
        let point = CoordinateConverter.toLayerPoint(globalPoint: global, in: frame)
        broadcastClick(point: point, kind: kind, root: layer)
    }

    // MARK: - Effect broadcast

    private func broadcastMove(point: CGPoint, root: CALayer) {
        let settings = store.settings

        if settings.highlightEnabled {
            let highlight = self.highlight ?? {
                let created = HighlightLayer(settings: settings)
                self.highlight = created
                return created
            }()

            // 커서가 새 화면 루트로 넘어갔으면 이전 루트에서 떼고 새 루트에 붙인다.
            if highlightRoot !== root || highlight.layer.superlayer !== root {
                highlight.layer.removeFromSuperlayer()
                highlight.apply(settings: settings)
                root.addSublayer(highlight.layer)
                highlightRoot = root
            }
            highlight.move(to: point)
        } else {
            highlight?.layer.removeFromSuperlayer()
            highlightRoot = nil
        }
    }

    private func broadcastClick(point: CGPoint, kind: ClickKind, root: CALayer) {
        // Task 7에서 클릭 이펙트 연결.
    }
}
