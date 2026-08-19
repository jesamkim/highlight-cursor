import CoreGraphics

/// macOS 전역 좌표(좌하단 원점)를 특정 화면의 레이어 로컬 좌표로 변환한다.
/// 반환값 x = `globalPoint.x - screenFrame.minX`, y = `globalPoint.y - screenFrame.minY`.
public enum CoordinateConverter {
    public static func toLayerPoint(globalPoint: CGPoint, in screenFrame: CGRect) -> CGPoint {
        CGPoint(x: globalPoint.x - screenFrame.minX, y: globalPoint.y - screenFrame.minY)
    }
}
