import Foundation

/// 클릭 이펙트 스타일 프리셋(애니 감성 4종).
/// - `ripple`: 링 하나가 퍼지며 사라지는 차분한 기본형(좌/우 색 구분).
/// - `sakura`: 분홍 벚꽃잎 여러 장이 회전·부유하며 페이드아웃.
/// - `energyBurst`: 중앙 링 + 방사형 광선이 팍 터졌다 수축(좌/우 색 구분).
/// - `sparkle`: 작은 별들이 사방으로 튀며 반짝이다 사라짐.
public enum ClickEffectStyle: String, Codable, CaseIterable, Sendable {
    case ripple
    case sakura
    case energyBurst
    case sparkle
}

/// 앱 전역 설정 모델. 각 효과의 on/off와 파라미터를 담는다.
/// 라이브러리 모듈(`HighlightCursorCore`)에 있으므로 앱·테스트가 함께 쓸 수 있도록
/// 타입과 멤버를 모두 `public`으로 노출한다.
public struct Settings: Codable, Equatable, Sendable {
    public var highlightEnabled: Bool = true
    public var highlightDiameter: Double = 50
    public var highlightColorHex: String = "#FFCC00"
    public var highlightOpacity: Double = 0.3
    public var clickEffectEnabled: Bool = true
    public var clickEffectStyle: ClickEffectStyle = .ripple
    public var spotlightEnabled: Bool = false
    public var spotlightRadius: Double = 150
    public var spotlightDimming: Double = 0.5
    public var trailEnabled: Bool = false
    public var trailMaxCount: Int = 8

    /// 크로스 모듈에서 사용 가능한 명시적 기본 이니셜라이저.
    /// 모든 저장 프로퍼티가 기본값을 가지므로 인자 없이 기본 설정을 만든다.
    public init() {}

    /// 저장된 값이 없을 때 사용하는 기본 설정.
    public static let `default` = Settings()

    private enum CodingKeys: String, CodingKey {
        case highlightEnabled, highlightDiameter, highlightColorHex, highlightOpacity
        case clickEffectEnabled, clickEffectStyle
        case spotlightEnabled, spotlightRadius, spotlightDimming
        case trailEnabled, trailMaxCount
    }

    /// 하위호환 디코딩. 기존에 저장된 JSON에는 새로 추가한 키(`clickEffectStyle` 등)가
    /// 없을 수 있다. Swift가 합성하는 Codable은 누락 키를 만나면 디코딩을 실패시키므로,
    /// 각 필드를 `decodeIfPresent`로 읽고 없으면 기본값을 채워 넣어 관대하게 디코딩한다.
    /// 이렇게 하면 앱 업데이트로 필드가 늘어나도 기존 사용자 설정이 통째로 초기화되지 않는다.
    public init(from decoder: Decoder) throws {
        self.init()
        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else { return }
        if let v = try container.decodeIfPresent(Bool.self, forKey: .highlightEnabled) { highlightEnabled = v }
        if let v = try container.decodeIfPresent(Double.self, forKey: .highlightDiameter) { highlightDiameter = v }
        if let v = try container.decodeIfPresent(String.self, forKey: .highlightColorHex) { highlightColorHex = v }
        if let v = try container.decodeIfPresent(Double.self, forKey: .highlightOpacity) { highlightOpacity = v }
        if let v = try container.decodeIfPresent(Bool.self, forKey: .clickEffectEnabled) { clickEffectEnabled = v }
        if let v = try container.decodeIfPresent(ClickEffectStyle.self, forKey: .clickEffectStyle) { clickEffectStyle = v }
        if let v = try container.decodeIfPresent(Bool.self, forKey: .spotlightEnabled) { spotlightEnabled = v }
        if let v = try container.decodeIfPresent(Double.self, forKey: .spotlightRadius) { spotlightRadius = v }
        if let v = try container.decodeIfPresent(Double.self, forKey: .spotlightDimming) { spotlightDimming = v }
        if let v = try container.decodeIfPresent(Bool.self, forKey: .trailEnabled) { trailEnabled = v }
        if let v = try container.decodeIfPresent(Int.self, forKey: .trailMaxCount) { trailMaxCount = v }
    }
}
