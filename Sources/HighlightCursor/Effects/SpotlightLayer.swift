import QuartzCore
import HighlightCursorCore

/// 화면 전체를 어둡게 덮고 커서 주변만 원형으로 밝게 뚫는 스포트라이트 레이어.
/// 어둠 레이어는 검정 + `spotlightDimming` 알파로 화면 전체를 채우고, 방사형
/// 그라데이션 마스크로 커서 주변을 뚫는다. 마스크 중심(원 안)은 알파 0이라 어둠이
/// 사라져 화면이 밝게 보이고, 바깥으로 갈수록 알파 1로 차올라 어둠이 남는다. 중심과
/// 가장자리 사이를 그라데이션으로 두어 경계가 날카롭게 잘리지 않고 부드럽게 페더링된다
/// (승인 사양: 스포트라이트 가장자리 부드럽게).
///
/// `move(to:)`는 마스크의 frame 위치만 옮기므로 그라데이션을 다시 렌더하지 않아
/// CPU 비용이 최소다. 마스크는 커서를 중심으로 한 정사각형(반경의 약 2배 크기)이고,
/// 그 밖은 마스크 레이어가 없어 알파 1(완전 불투명)로 취급되어 어둠이 그대로 유지된다.
@MainActor
final class SpotlightLayer {
    /// 화면 전체를 덮는 어둠 레이어(EffectCoordinator가 root의 맨 아래에 붙인다).
    let layer = CALayer()

    /// 방사형 그라데이션 마스크. 중심 알파 0(구멍) → 가장자리 알파 1(어둠)로 부드럽게 전환.
    private let holeMask = CAGradientLayer()

    private var radius: CGFloat = 150
    private var screenSize: CGSize = .zero

    init(settings: Settings, screenSize: CGSize) {
        apply(settings: settings, screenSize: screenSize)
    }

    /// 어둡기·반경·화면 크기를 설정값에서 반영한다. 화면이 바뀌면 크기를 다시 잡는다.
    func apply(settings: Settings, screenSize: CGSize) {
        self.radius = CGFloat(settings.spotlightRadius)
        self.screenSize = screenSize

        layer.frame = CGRect(origin: .zero, size: screenSize)
        layer.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: settings.spotlightDimming)

        // 마스크는 화면 전체를 덮는다(부분 마스크는 바깥을 알파 0으로 잘라내 반대로
        // 화면 전체가 밝아지므로 안 된다). 방사형 그라데이션의 중심을 커서로 옮겨
        // 중심은 투명(밝음), 바깥은 불투명(어둠)으로 만든다.
        holeMask.frame = layer.bounds
        holeMask.type = .radial
        holeMask.colors = [
            CGColor(gray: 0, alpha: 0),   // 중심: 구멍(밝음)
            CGColor(gray: 0, alpha: 0),   // 반경 안쪽까지 완전히 밝게 유지
            CGColor(gray: 0, alpha: 1)    // 가장자리 바깥: 어둠
        ]
        // 안쪽은 완전 투명, 이후 반경 경계까지 부드럽게 불투명으로 차오른다(페더).
        holeMask.locations = [0.0, 0.7, 1.0]
        layer.mask = holeMask

        // 아직 실제 커서 위치가 없으므로 화면 중앙에 임시로 구멍을 둔다.
        moveHole(to: CGPoint(x: screenSize.width / 2, y: screenSize.height / 2))
    }

    /// 커서 위치에 맞춰 그라데이션 중심(start/end point)만 옮긴다(마스크 프레임·색은 그대로).
    func move(to point: CGPoint) {
        moveHole(to: point)
    }

    /// 방사형 그라데이션의 중심을 커서로, 반경 끝점을 `radius`만큼 떨어진 지점으로 잡는다.
    /// startPoint/endPoint는 단위 좌표(0~1)이므로 화면 크기로 정규화한다.
    /// 입력 point는 이미 오버레이 레이어 좌표(bottom-left origin)이고, layer-backed
    /// NSView의 레이어 기하와 CAGradientLayer 단위좌표가 같은 원점을 쓰므로 y를
    /// 다시 뒤집지 않는다(뒤집으면 스포트라이트가 커서와 상하 반대로 움직인다).
    private func moveHole(to point: CGPoint) {
        let w = max(screenSize.width, 1)
        let h = max(screenSize.height, 1)
        let cx = point.x / w
        let cy = point.y / h
        holeMask.startPoint = CGPoint(x: cx, y: cy)
        // 반경을 x/y 단위 비율로 환산해 원형에 가깝게 끝점을 잡는다.
        holeMask.endPoint = CGPoint(x: cx + radius / w, y: cy + radius / h)
    }
}
