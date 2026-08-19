import HighlightCursorCore

// 테스트 실행 진입점. 각 태스크가 자기 테스트 함수를 여기에 배선한다.
// 실행: ./scripts/test.sh (실패 시 non-zero 종료)

TinyTest.test("placeholder") {
    TinyTest.check(true, "sanity")
}

runSettingsTests()      // Task 2
runCoordinateTests()    // Task 3

TinyTest.summarize()
