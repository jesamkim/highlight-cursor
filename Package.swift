// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "HighlightCursor",
    platforms: [.macOS(.v14)],
    targets: [
        // 순수 로직 + TinyTest 셤 (앱과 테스트가 공유)
        .target(name: "HighlightCursorCore", path: "Sources/HighlightCursorCore"),
        // 실행 앱
        .executableTarget(
            name: "HighlightCursor",
            dependencies: ["HighlightCursorCore"],
            path: "Sources/HighlightCursor"
        ),
        // 테스트 실행 파일 (swift test 대신 scripts/test.sh로 구동)
        .executableTarget(
            name: "HighlightCursorTests",
            dependencies: ["HighlightCursorCore"],
            path: "Tests/HighlightCursorTests"
        ),
    ]
)
