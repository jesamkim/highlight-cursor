# Highlight Cursor — 설계 문서

작성일: 2026-08-19
상태: 승인됨 (구현 계획 단계로 진행)

## 1. 목적과 범위

macOS에서 마우스 커서에 시각 효과를 입혀 발표·화면 녹화·강의 시 포인터를 눈에 잘 띄게 만드는 앱을 직접 구현한다. 상용 앱(Mouse Pro, Mouzz, Cursor Pro, ScreenPointer 등)과 동급 기능을 목표로 하되, **리소스 최적화(낮은 CPU·배터리 소모)** 를 최우선 설계 제약으로 둔다.

### 포함 기능 (풀 기능)
- 커서 하이라이트 (항상 켜짐)
- 클릭 이펙트 (좌/우 클릭 물결)
- 스포트라이트 (커서 주변만 밝게, 나머지 어둡게 — 토글)
- 커서 트레일 (잔상 — 토글, 기본 꺼짐)
- 전역 단축키 토글 + 메뉴바 제어

### 범위에서 제외 (YAGNI)
- 코드 서명·공증·App Store 제출 (개인 사용 목적)
- 정식 `.xcodeproj` 기반 빌드 (Xcode.app 미설치, SPM로 진행)
- 화면 확대(줌)·주석 그리기·녹화 기능

## 2. 대상 환경

- macOS 26.6.1 (arm64), Swift 6.3.3
- 빌드: Swift Package Manager (`swift build`) + 수동 `.app` 번들 조립 (Xcode.app 불필요, Command Line Tools만 사용)
- 프레임워크: AppKit + Core Animation (QuartzCore) + CoreGraphics
- 배포 대상: 본인 맥북 1대 (개인 사용)

## 3. 기능 사양 (승인된 기본값)

| 기능 | 기본값 | 설정 가능 |
|---|---|---|
| 커서 하이라이트 | 지름 ~50px, 노란색, 30% 불투명도, 부드러운 글로우 테두리 | 색·크기·투명도 |
| 클릭 이펙트 | 클릭 위치에서 물결(ring)이 ~0.4초 퍼지며 소멸, 좌/우 색 구분 | 색·지속시간 on/off |
| 스포트라이트 | 반경 ~150px 원만 밝게, 화면 어둡기 50%, 가장자리 부드럽게 | 반경·어둡기 |
| 커서 트레일 | 빠른 이동 시 잔상, 최대 8개, 기본 꺼짐 | on/off·개수 |
| 단축키 | 하이라이트 ⌥⌘H, 스포트라이트 ⌥⌘S, 트레일 ⌥⌘T | 재지정 |

- 멀티 모니터: 지원. 커서가 있는 화면에 효과가 따라간다.
- 앱 형태: 메뉴바 액세서리 앱 (`LSUIElement = true`), Dock 아이콘 없음.

## 4. 아키텍처

```
마우스 이벤트 (이동/클릭)
        │
   [EventMonitor]  ← NSEvent 전역 모니터 + CGEventTap
        │  커서 위치·클릭 종류 전달
        ▼
   [EffectCoordinator]  ← 효과 on/off 상태 관리, 위치 브로드캐스트
        │
        ├──▶ [HighlightLayer]   커서 따라다니는 원
        ├──▶ [ClickEffectLayer] 클릭 시 물결
        ├──▶ [SpotlightLayer]   주변 어둡게
        └──▶ [TrailLayer]       잔상
             │ (모두 하나의 투명 OverlayWindow 위 Core Animation 레이어)
             ▼
   [OverlayWindowController]  ← 화면별 투명 클릭-통과 창
```

### 핵심 설계 원칙
- 오버레이 창은 클릭 통과(`ignoresMouseEvents = true`) — 사용자의 실제 클릭을 가로막지 않는다.
- 모든 시각 효과는 Core Animation 레이어로 그려 GPU가 처리한다. CPU는 위치 갱신만 담당.
- 마우스가 멈추면 렌더링도 멈춘다 (상시 60fps 금지).

## 5. 모듈 구성

```
highlight-cursor/
├── Package.swift
├── Sources/HighlightCursor/
│   ├── main.swift                  앱 진입점, NSApplication 기동
│   ├── AppDelegate.swift           앱 수명주기, 메뉴바 셋업
│   ├── MenuBarController.swift     메뉴바 아이콘·메뉴·토글
│   ├── Input/
│   │   ├── EventMonitor.swift      마우스 이동/클릭 감지
│   │   └── AccessibilityGuard.swift 접근성 권한 확인·요청
│   ├── Overlay/
│   │   ├── OverlayWindow.swift      투명·클릭통과 NSWindow
│   │   ├── OverlayWindowController.swift  화면별 창 생성·관리
│   │   └── EffectCoordinator.swift  효과 상태, 위치 브로드캐스트
│   ├── Effects/
│   │   ├── HighlightLayer.swift     커서 원
│   │   ├── ClickEffectLayer.swift   클릭 물결
│   │   ├── SpotlightLayer.swift     주변 어둡게 마스크
│   │   └── TrailLayer.swift         잔상
│   ├── Settings/
│   │   ├── Settings.swift           설정 모델
│   │   ├── SettingsStore.swift      UserDefaults 저장·로드
│   │   └── SettingsWindow.swift     설정 창 UI
│   └── Shortcuts/
│       └── HotkeyManager.swift      전역 단축키
├── Resources/
│   └── Info.plist                   LSUIElement, 접근성 usage 설명
├── scripts/
│   ├── build_app.sh                 swift build → .app 번들 조립
│   └── run.sh                        빌드 후 실행
└── Tests/HighlightCursorTests/      설정·좌표·상태 로직 단위 테스트
```

각 파일은 하나의 명확한 책임만 갖는다. 잘 정의된 인터페이스로 통신하고 독립적으로 이해·테스트할 수 있게 한다.

## 6. 리소스 최적화 전략 (핵심)

1. **이벤트 기반, 폴링 금지**: 타이머 폴링 대신 `NSEvent` 전역 모니터가 마우스가 실제로 움직일 때만 콜백을 준다. 정지 시 CPU 사용 0에 수렴.
2. **레이어 위치 갱신은 애니메이션 없이 즉시**: `CATransaction`으로 암묵적 애니메이션을 꺼(`disableActions`) 매 이동마다 불필요한 보간 연산을 없앤다.
3. **스포트라이트 마스크의 효율적 갱신**: 어둠 레이어는 한 번만 그리고 밝은 구멍(원)의 위치만 옮긴다. 매번 전체 마스크를 다시 렌더링하지 않는다.
4. **꺼진 효과는 레이어 자체 제거**: 사용하지 않는 효과 레이어를 창에서 떼어내 메모리·컴포지팅 비용을 0으로.
5. **트레일 상한**: 잔상 최대 개수를 두고 오래된 것부터 GPU 애니메이션으로 자연 소멸.
6. **멀티모니터 지연 생성**: 커서가 있는 화면 오버레이만 활성으로 두고 다른 화면은 필요 시 활성화.

목표 지표: 활발한 이동 시 CPU 한 자릿수 %, 정지 시 거의 0%, 배터리 영향 미미.

## 7. 접근성 권한·에러 처리

- 전역 마우스/키보드 이벤트 감지에 macOS 접근성 권한 필요. 최초 실행 시 권한이 없으면 안내 다이얼로그를 띄우고 시스템 설정의 해당 창을 연다. 권한 부여 전에는 효과가 비활성이되 앱이 죽지 않도록 우아하게 처리.
- 디스플레이 구성 변경(모니터 연결/해제), 사용자 전환 감지 시 오버레이 창을 재구성.

## 8. 테스트 전략

- 순수 로직(설정 저장/로드, 좌표 변환, 트레일 상한, 효과 상태 전이)은 SPM 단위 테스트로 커버.
- 시각적 렌더링은 자동 테스트가 어려우므로 빌드 후 실제 실행·관찰로 검증.

## 9. 개발 워크플로우

1. 기능 단위로 구현 후 `scripts/build_app.sh`로 컴파일·앱 조립 검증.
2. 각 의미 있는 diff마다 orca-cli를 통한 Codex GPT-5.6(Terra) 코드 리뷰 실행. 작은 diff(≤3파일)는 직접, 큰 diff(4+파일)는 비동기 fire-and-forget + 폴링.
3. 리뷰의 정당한 지적(critical/high)은 반영, false positive는 근거와 함께 배제.
4. 단위 테스트 green + 실제 실행 확인 후 다음 기능으로.

## 10. 구현 순서

1. 뼈대: 메뉴바 앱 + 투명 클릭통과 오버레이 창 + 이벤트 모니터 + 접근성 권한
2. 커서 하이라이트
3. 클릭 이펙트
4. 스포트라이트
5. 커서 트레일
6. 전역 단축키
7. 설정 창

각 단계는 독립적으로 동작·검증 가능하도록 쌓는다.
