import Foundation

/// 의존성 없는 초경량 테스트 셤.
/// 이 환경(Command Line Tools만 설치)에는 XCTest·swift-testing이 없어
/// `swift test`를 쓸 수 없다. 대신 이 셤과 테스트 실행 타깃 + scripts/test.sh로
/// 순수 로직을 검증한다.
/// 테스트는 단일 스레드에서 순차 실행되므로 MainActor로 격리해
/// Swift 6 동시성 검사(가변 전역 상태)를 통과시킨다.
@MainActor
public enum TinyTest {
    public private(set) static var failures: [String] = []
    public private(set) static var passed = 0

    public static func check(_ condition: Bool, _ message: @autoclosure () -> String,
                             file: StaticString = #file, line: UInt = #line) {
        if condition {
            passed += 1
        } else {
            failures.append("[\(file):\(line)] \(message())")
        }
    }

    public static func equal<T: Equatable>(_ a: T, _ b: T, _ label: String = "",
                                           file: StaticString = #file, line: UInt = #line) {
        check(a == b, "\(label) expected \(b), got \(a)", file: file, line: line)
    }

    /// 부동소수 비교(허용 오차).
    public static func equalApprox(_ a: Double, _ b: Double, tolerance: Double = 0.01,
                                   _ label: String = "",
                                   file: StaticString = #file, line: UInt = #line) {
        check(abs(a - b) <= tolerance, "\(label) expected \(b)±\(tolerance), got \(a)",
              file: file, line: line)
    }

    /// 하나의 테스트 케이스를 이름과 함께 실행한다.
    public static func test(_ name: String, _ body: () -> Void) {
        let before = failures.count
        body()
        let newFailures = failures.count - before
        let mark = newFailures == 0 ? "✅" : "❌"
        FileHandle.standardError.write(Data("\(mark) \(name)\n".utf8))
    }

    /// 전체 결과를 출력하고 실패가 있으면 프로세스를 non-zero로 종료한다.
    public static func summarize() -> Never {
        let err = FileHandle.standardError
        err.write(Data("\n--- TinyTest: \(passed) checks passed, \(failures.count) failed ---\n".utf8))
        for f in failures { err.write(Data("  \(f)\n".utf8)) }
        exit(failures.isEmpty ? 0 : 1)
    }
}
