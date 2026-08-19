import AppKit

/// `NSColorWell` 연동을 위한 hex ↔ `NSColor` 변환. `ColorHex`(Core)는 CGColor만
/// 다루고 AppKit에 의존하지 않으므로, AppKit 전용 변환은 앱 타깃에 둔다.
enum ColorWellSupport {
    static func nsColor(fromHex hex: String) -> NSColor {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else {
            return NSColor(red: 1, green: 0.8, blue: 0, alpha: 1)
        }
        let r = CGFloat((v >> 16) & 0xFF) / 255.0
        let g = CGFloat((v >> 8) & 0xFF) / 255.0
        let b = CGFloat(v & 0xFF) / 255.0
        return NSColor(red: r, green: g, blue: b, alpha: 1)
    }

    static func hexString(from color: NSColor) -> String {
        guard let rgb = color.usingColorSpace(.deviceRGB) else { return "#FFCC00" }
        let r = Int(rgb.redComponent * 255)
        let g = Int(rgb.greenComponent * 255)
        let b = Int(rgb.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
