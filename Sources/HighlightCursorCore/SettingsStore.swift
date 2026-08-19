import Foundation

/// `Settings`를 `UserDefaults`에 JSON으로 직렬화해 저장·복원하는 저장소.
/// 저장 키는 "settings.v1"이며, 저장된 값이 없거나 디코딩에 실패하면
/// `Settings.default`을 돌려준다.
public final class SettingsStore {
    private let defaults: UserDefaults
    private let key = "settings.v1"

    /// 테스트에서 격리된 suite를 주입할 수 있도록 `UserDefaults`를 인자로 받는다.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var settings: Settings {
        get {
            guard let data = defaults.data(forKey: key),
                  let decoded = try? JSONDecoder().decode(Settings.self, from: data)
            else { return .default }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: key)
            }
        }
    }
}
