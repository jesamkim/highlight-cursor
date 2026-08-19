import HighlightCursorCore

// 테스트 실행 진입점. 각 태스크가 여기에 test(...) 블록을 추가한다.
// 실행: ./scripts/test.sh (실패 시 non-zero 종료)

TinyTest.test("placeholder") {
    TinyTest.check(true, "sanity")
}

TinyTest.summarize()
