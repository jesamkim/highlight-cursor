import Foundation

/// 앱 전역 설정 모델. 각 효과의 on/off와 파라미터를 담는다.
/// 라이브러리 모듈(`HighlightCursorCore`)에 있으므로 앱·테스트가 함께 쓸 수 있도록
/// 타입과 멤버를 모두 `public`으로 노출한다.
public struct Settings: Codable, Equatable, Sendable {
    public var highlightEnabled: Bool = true
    public var highlightDiameter: Double = 50
    public var highlightColorHex: String = "#FFCC00"
    public var highlightOpacity: Double = 0.3
    public var clickEffectEnabled: Bool = true
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
}
