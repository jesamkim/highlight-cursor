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

    // Task 8: 스포트라이트(화면을 어둡게 덮고 커서 주변만 밝게 뚫는 딤 배경).
    // 하이라이트/클릭 이펙트보다 아래(zPosition)에 깔려 배경 역할을 한다.
    private var spotlight: SpotlightLayer?
    private var spotlightRoot: CALayer?

    // Task 7: 클릭 이펙트(일회성 링 물결).
    private let clickEffect = ClickEffectLayer()

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

        // Task 8: 스포트라이트를 하이라이트보다 먼저 처리해 맨 아래에 깔리게 한다.
        // insert at index 0 + zPosition을 낮게 주어, 이후 하이라이트/클릭 링이 항상 위에 보이게 한다.
        if settings.spotlightEnabled {
            let screenSize = root.bounds.size
            let spotlight = self.spotlight ?? {
                let created = SpotlightLayer(settings: settings, screenSize: screenSize)
                self.spotlight = created
                return created
            }()

            // 커서가 새 화면 루트로 넘어갔으면 이전 루트에서 떼고 새 루트(새 크기)에 다시 붙인다.
            if spotlightRoot !== root || spotlight.layer.superlayer !== root {
                spotlight.layer.removeFromSuperlayer()
                spotlight.apply(settings: settings, screenSize: screenSize)
                spotlight.layer.zPosition = -100   // 다른 효과 레이어보다 항상 아래
                root.insertSublayer(spotlight.layer, at: 0)
                spotlightRoot = root
            }
            spotlight.move(to: point)
        } else {
            spotlight?.layer.removeFromSuperlayer()
            spotlightRoot = nil
        }

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
        // Task 7/15: 클릭 이펙트가 켜져 있으면 선택된 스타일로 클릭 위치에 이펙트를 방출한다.
        let settings = store.settings
        if settings.clickEffectEnabled {
            clickEffect.emit(at: point, kind: kind, style: settings.clickEffectStyle, on: root)
        }
    }

    // MARK: - Settings refresh

    /// 메뉴/단축키로 설정이 바뀌었을 때 살아있는 효과에 즉시 반영한다.
    /// 하이라이트와 스포트라이트를 처리한다.
    func refreshSettings() {
        let settings = store.settings
        let global = NSEvent.mouseLocation
        let root = controller.rootLayer(forGlobal: global)

        if settings.spotlightEnabled {
            // 켜져 있으면 현재 커서 위치에 즉시 반영한다. 마우스를 움직이지 않아도
            // 반경·어둡기 변경과 재활성화가 바로 보이도록 broadcastMove를 태운다.
            if let (layer, _) = root {
                spotlight?.apply(settings: settings, screenSize: layer.bounds.size)
            }
        } else {
            spotlight?.layer.removeFromSuperlayer()
            spotlightRoot = nil
        }

        if settings.highlightEnabled {
            // 켜져 있으면 현재 커서 위치에 즉시 반영한다. 마우스를 움직이지 않아도
            // 지름·색·투명도 변경과 재활성화가 바로 보이도록 broadcastMove를 태운다.
            highlight?.apply(settings: settings)
        } else {
            // 꺼지면 레이어를 떼고 캐시를 비워 재활성화 시 깨끗하게 다시 붙게 한다.
            highlight?.layer.removeFromSuperlayer()
            highlightRoot = nil
        }

        // 하이라이트/스포트라이트가 켜져 있으면 현재 위치에 즉시 그린다.
        if (settings.highlightEnabled || settings.spotlightEnabled), let (layer, frame) = root {
            let point = CoordinateConverter.toLayerPoint(globalPoint: global, in: frame)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            broadcastMove(point: point, root: layer)
            CATransaction.commit()
        }
        // Task 9: refresh trail here
    }
}
