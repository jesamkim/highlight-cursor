import CoreGraphics

/// "#RRGGBB" 문자열을 `CGColor`로 파싱한다. 형식이 잘못되면 노란색으로 대체한다.
/// 라이브러리 모듈에 두어 앱과 테스트가 함께 검증할 수 있도록 `public`으로 노출한다.
public enum ColorHex {
    public static func cgColor(_ hex: String, alpha: Double) -> CGColor {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else {
            return CGColor(red: 1, green: 0.8, blue: 0, alpha: alpha)
        }
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8) & 0xFF) / 255.0
        let b = Double(v & 0xFF) / 255.0
        return CGColor(red: r, green: g, blue: b, alpha: alpha)
    }
}
