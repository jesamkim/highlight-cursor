# Highlight Cursor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** macOS 커서에 하이라이트·클릭 이펙트·스포트라이트·트레일 효과를 입히는, 리소스 최적화된 메뉴바 앱을 SPM으로 빌드한다.

**Architecture:** 투명·클릭통과 오버레이 창(화면별) 위에 Core Animation 레이어로 각 효과를 그린다. `NSEvent` 전역 모니터가 마우스 이동/클릭 시에만 콜백을 주고(폴링 없음), `EffectCoordinator`가 위치를 각 효과 레이어에 브로드캐스트한다. GPU가 렌더링을 담당하고 CPU는 위치 갱신만 한다.

**Tech Stack:** Swift 6.3, AppKit, Core Animation(QuartzCore), CoreGraphics, Swift Package Manager. 빌드 후 수동 `.app` 번들 조립(Xcode.app 불필요).

**Spec:** `/Users/jesamkim/QCLI/highlight-cursor/docs/superpowers/specs/2026-08-19-highlight-cursor-design.md`

## Global Constraints

- macOS 26+ (arm64), Swift 6.3.3, Command Line Tools만 사용(Xcode.app 없음). 빌드는 `swift build`.
- 앱은 메뉴바 액세서리 형태: `Info.plist`의 `LSUIElement = true`, Dock 아이콘 없음.
- 오버레이 창은 항상 `ignoresMouseEvents = true`로 클릭을 통과시킨다. 사용자의 실제 클릭을 절대 가로막지 않는다.
- 커서 위치 갱신 시 `CATransaction.setDisableActions(true)`로 암묵적 애니메이션을 끈다.
- 타이머 폴링 금지. 마우스 이벤트 콜백 기반으로만 동작한다.
- 꺼진 효과 레이어는 창(super layer)에서 제거해 컴포지팅 비용을 0으로 만든다.
- **테스트 전략(환경 제약 반영)**: 이 환경은 Command Line Tools만 있어 XCTest·swift-testing이 모두 없다. 따라서 XCTest 대신 의존성 없는 자체 `TinyTest` 셤(`Sources/HighlightCursorCore/TinyTest.swift`)으로 테스트한다. 순수 로직은 라이브러리 타깃 `HighlightCursorCore`에 넣고, 실행 타깃 `HighlightCursor`와 테스트 실행 타깃 `HighlightCursorTests`가 이를 import한다. 테스트는 `swift test`가 아니라 `./scripts/test.sh`(테스트 실행 파일을 빌드·실행, 실패 시 non-zero 종료)로 돌린다. 각 태스크는 독립적으로 빌드·검증 가능해야 한다.
- 좌표계: macOS 전역 좌표는 좌하단 원점(bottom-left). 오버레이 그리기 좌표 변환 시 주 화면 높이를 기준으로 뒤집는다.

---

### Task 1: 프로젝트 뼈대 + 빌드 스크립트

**Files:**
- Create: `/Users/jesamkim/QCLI/highlight-cursor/Package.swift`
- Create: `/Users/jesamkim/QCLI/highlight-cursor/Sources/HighlightCursor/main.swift`
- Create: `/Users/jesamkim/QCLI/highlight-cursor/Sources/HighlightCursor/AppDelegate.swift`
- Create: `/Users/jesamkim/QCLI/highlight-cursor/Resources/Info.plist`
- Create: `/Users/jesamkim/QCLI/highlight-cursor/scripts/build_app.sh`
- Create: `/Users/jesamkim/QCLI/highlight-cursor/scripts/run.sh`
- Create: `/Users/jesamkim/QCLI/highlight-cursor/.gitignore`

**Interfaces:**
- Produces: `AppDelegate: NSObject, NSApplicationDelegate` — 이후 모든 태스크가 붙는 앱 진입점. `build_app.sh`는 `swift build -c release` 산출물을 `HighlightCursor.app/Contents/MacOS/`에 넣고 `Info.plist`를 복사한다.

- [ ] **Step 1: `git init` 및 `.gitignore` 작성**

```bash
cd /Users/jesamkim/QCLI/highlight-cursor && git init
```

`.gitignore`:
```
.build/
*.app/
.DS_Store
```

- [ ] **Step 2: `Package.swift` 작성**

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "HighlightCursor",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "HighlightCursor", path: "Sources/HighlightCursor"),
        .testTarget(name: "HighlightCursorTests", dependencies: ["HighlightCursor"], path: "Tests/HighlightCursorTests"),
    ]
)
```

- [ ] **Step 3: 최소 `main.swift` + `AppDelegate.swift` 작성**

`main.swift`:
```swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
```

`AppDelegate.swift`:
```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("HighlightCursor launched")
    }
}
```

- [ ] **Step 4: `Info.plist` 작성**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>HighlightCursor</string>
  <key>CFBundleIdentifier</key><string>com.jesamkim.highlightcursor</string>
  <key>CFBundleExecutable</key><string>HighlightCursor</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>LSUIElement</key><true/>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
</dict></plist>
```

- [ ] **Step 5: `build_app.sh` 작성 (swift build → .app 조립)**

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP="HighlightCursor.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp ".build/release/HighlightCursor" "$APP/Contents/MacOS/"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"
echo "Built $APP"
```

`run.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build_app.sh
open "HighlightCursor.app"
```

- [ ] **Step 6: 빌드·실행 검증**

Run: `chmod +x scripts/*.sh && ./scripts/build_app.sh`
Expected: `.build/release/HighlightCursor` 생성, `HighlightCursor.app` 조립 완료, 컴파일 에러 없음.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat: SPM skeleton, menu-bar accessory app, build script"
```

---

### Task 2: 설정 모델 + 저장소 (단위 테스트 대상)

**Files:**
- Create: `Sources/HighlightCursor/Settings/Settings.swift`
- Create: `Sources/HighlightCursor/Settings/SettingsStore.swift`
- Test: `Tests/HighlightCursorTests/SettingsStoreTests.swift`

**Interfaces:**
- Produces:
  - `struct Settings: Codable, Equatable` — 필드: `highlightEnabled: Bool`, `highlightDiameter: Double`(기본 50), `highlightColorHex: String`(기본 "#FFCC00"), `highlightOpacity: Double`(기본 0.3), `clickEffectEnabled: Bool`(기본 true), `spotlightEnabled: Bool`(기본 false), `spotlightRadius: Double`(기본 150), `spotlightDimming: Double`(기본 0.5), `trailEnabled: Bool`(기본 false), `trailMaxCount: Int`(기본 8). `static var `default`: Settings`.
  - `final class SettingsStore` — `init(defaults: UserDefaults = .standard)`, `var settings: Settings { get set }`(set 시 JSON 인코딩해 저장), `load()`가 저장값 없으면 `.default` 반환.

- [ ] **Step 1: 실패하는 테스트 작성**

```swift
import XCTest
@testable import HighlightCursor

final class SettingsStoreTests: XCTestCase {
    func test_load_returnsDefault_whenEmpty() {
        let defaults = UserDefaults(suiteName: "test-empty-\(UUID())")!
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.settings, Settings.default)
    }

    func test_roundTrip_persistsChanges() {
        let defaults = UserDefaults(suiteName: "test-rt-\(UUID())")!
        var store = SettingsStore(defaults: defaults)
        var s = store.settings
        s.spotlightEnabled = true
        s.highlightDiameter = 72
        store.settings = s
        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertTrue(reloaded.settings.spotlightEnabled)
        XCTAssertEqual(reloaded.settings.highlightDiameter, 72)
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `swift test --filter SettingsStoreTests`
Expected: FAIL — `Settings`/`SettingsStore` 미정의.

- [ ] **Step 3: `Settings.swift` + `SettingsStore.swift` 구현**

`Settings.swift`:
```swift
import Foundation

struct Settings: Codable, Equatable {
    var highlightEnabled: Bool = true
    var highlightDiameter: Double = 50
    var highlightColorHex: String = "#FFCC00"
    var highlightOpacity: Double = 0.3
    var clickEffectEnabled: Bool = true
    var spotlightEnabled: Bool = false
    var spotlightRadius: Double = 150
    var spotlightDimming: Double = 0.5
    var trailEnabled: Bool = false
    var trailMaxCount: Int = 8

    static let `default` = Settings()
}
```

`SettingsStore.swift`:
```swift
import Foundation

final class SettingsStore {
    private let defaults: UserDefaults
    private let key = "settings.v1"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var settings: Settings {
        get {
            guard let data = defaults.data(forKey: key),
                  let s = try? JSONDecoder().decode(Settings.self, from: data)
            else { return .default }
            return s
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: key)
            }
        }
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `swift test --filter SettingsStoreTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: settings model + UserDefaults-backed store with tests"
```

---

### Task 3: 좌표 변환 유틸 (단위 테스트 대상)

**Files:**
- Create: `Sources/HighlightCursor/Overlay/CoordinateConverter.swift`
- Test: `Tests/HighlightCursorTests/CoordinateConverterTests.swift`

**Interfaces:**
- Produces: `enum CoordinateConverter { static func toLayerPoint(globalPoint: CGPoint, in screenFrame: CGRect) -> CGPoint }` — macOS 전역 좌표(bottom-left origin)를 특정 화면의 레이어 로컬 좌표로 변환. 반환값 x = `globalPoint.x - screenFrame.minX`, y = `globalPoint.y - screenFrame.minY`.

- [ ] **Step 1: 실패하는 테스트 작성**

```swift
import XCTest
@testable import HighlightCursor

final class CoordinateConverterTests: XCTestCase {
    func test_originScreen() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let p = CoordinateConverter.toLayerPoint(globalPoint: CGPoint(x: 100, y: 200), in: screen)
        XCTAssertEqual(p, CGPoint(x: 100, y: 200))
    }

    func test_offsetScreen() {
        let screen = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
        let p = CoordinateConverter.toLayerPoint(globalPoint: CGPoint(x: 1500, y: 300), in: screen)
        XCTAssertEqual(p, CGPoint(x: 60, y: 300))
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `swift test --filter CoordinateConverterTests`
Expected: FAIL — 미정의.

- [ ] **Step 3: 구현**

```swift
import CoreGraphics

enum CoordinateConverter {
    static func toLayerPoint(globalPoint: CGPoint, in screenFrame: CGRect) -> CGPoint {
        CGPoint(x: globalPoint.x - screenFrame.minX, y: globalPoint.y - screenFrame.minY)
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `swift test --filter CoordinateConverterTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: coordinate converter (global → layer) with tests"
```

---

### Task 4: 접근성 권한 가드 + 이벤트 모니터

**Files:**
- Create: `Sources/HighlightCursor/Input/AccessibilityGuard.swift`
- Create: `Sources/HighlightCursor/Input/EventMonitor.swift`
- Modify: `Sources/HighlightCursor/AppDelegate.swift`

**Interfaces:**
- Consumes: `AppDelegate`(Task 1).
- Produces:
  - `enum AccessibilityGuard { static func isTrusted() -> Bool; static func promptIfNeeded() }` — `AXIsProcessTrustedWithOptions`로 권한 확인, 없으면 시스템 프롬프트 유도.
  - `final class EventMonitor` — `var onMove: ((CGPoint) -> Void)?`, `var onClick: ((CGPoint, ClickKind) -> Void)?`, `func start()`, `func stop()`. `enum ClickKind { case left, right }`. 내부는 `NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .leftMouseDragged])`. 콜백은 `NSEvent.mouseLocation`(전역 좌표) 전달. **타이머 없음.**

- [ ] **Step 1: `AccessibilityGuard.swift` 구현**

```swift
import ApplicationServices

enum AccessibilityGuard {
    static func isTrusted() -> Bool { AXIsProcessTrusted() }

    static func promptIfNeeded() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(opts as CFDictionary)
    }
}
```

- [ ] **Step 2: `EventMonitor.swift` 구현**

```swift
import AppKit

enum ClickKind { case left, right }

final class EventMonitor {
    var onMove: ((CGPoint) -> Void)?
    var onClick: ((CGPoint, ClickKind) -> Void)?
    private var monitor: Any?

    func start() {
        stop()
        monitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            let loc = NSEvent.mouseLocation
            switch event.type {
            case .leftMouseDown: self?.onClick?(loc, .left)
            case .rightMouseDown: self?.onClick?(loc, .right)
            default: self?.onMove?(loc)
            }
        }
    }

    func stop() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }
}
```

- [ ] **Step 3: `AppDelegate`에서 권한 확인 + 모니터 기동, 로그로 검증**

`applicationDidFinishLaunching`에 추가:
```swift
private let eventMonitor = EventMonitor()

func applicationDidFinishLaunching(_ notification: Notification) {
    AccessibilityGuard.promptIfNeeded()
    eventMonitor.onMove = { p in NSLog("move \(p.x),\(p.y)") }
    eventMonitor.onClick = { p, kind in NSLog("click \(kind) \(p.x),\(p.y)") }
    eventMonitor.start()
}
```

- [ ] **Step 4: 빌드 + 실제 실행으로 이벤트 로그 확인**

Run: `./scripts/build_app.sh && open HighlightCursor.app`
접근성 권한 부여 후 마우스 이동/클릭 시 Console.app에 `move`/`click` 로그가 찍히는지 확인. 마우스를 멈추면 로그가 멈추는지(폴링 없음) 확인.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: accessibility guard + event-driven mouse monitor"
```

---

### Task 5: 투명 오버레이 창 + 화면별 관리 + EffectCoordinator

**Files:**
- Create: `Sources/HighlightCursor/Overlay/OverlayWindow.swift`
- Create: `Sources/HighlightCursor/Overlay/OverlayWindowController.swift`
- Create: `Sources/HighlightCursor/Overlay/EffectCoordinator.swift`
- Modify: `Sources/HighlightCursor/AppDelegate.swift`

**Interfaces:**
- Consumes: `EventMonitor`(Task 4), `CoordinateConverter`(Task 3), `Settings`(Task 2).
- Produces:
  - `final class OverlayWindow: NSWindow` — `init(screen: NSScreen)`. 속성: `isOpaque=false`, `backgroundColor=.clear`, `ignoresMouseEvents=true`, `level=.screenSaver`, `collectionBehavior=[.canJoinAllSpaces, .stationary]`, `hasShadow=false`. 루트 `contentView`는 layer-backed(`wantsLayer=true`).
  - `final class OverlayWindowController` — `func window(for screenFrame: CGRect) -> OverlayWindow?`(커서가 속한 화면 창 반환), `func rootLayer(for screenFrame: CGRect) -> CALayer?`, `func rebuildForCurrentScreens()`(디스플레이 변경 시). 화면별 창을 `[CGRect: OverlayWindow]`로 보관.
  - `final class EffectCoordinator` — `init(controller: OverlayWindowController, settingsStore: SettingsStore)`, `func handleMove(global: CGPoint)`, `func handleClick(global: CGPoint, kind: ClickKind)`. move/click을 받아 커서가 속한 화면을 찾고 레이어 좌표로 변환해 각 효과에 전달(이 태스크에서는 브로드캐스트 골격만; 실제 효과는 Task 6~9에서 붙임).

- [ ] **Step 1: `OverlayWindow.swift` 구현**

```swift
import AppKit

final class OverlayWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        let view = NSView(frame: screen.frame)
        view.wantsLayer = true
        contentView = view
        setFrame(screen.frame, display: true)
        orderFrontRegardless()
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
```

- [ ] **Step 2: `OverlayWindowController.swift` 구현**

```swift
import AppKit

final class OverlayWindowController {
    private var windows: [OverlayWindow] = []

    init() { rebuildForCurrentScreens() }

    func rebuildForCurrentScreens() {
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.map { OverlayWindow(screen: $0) }
    }

    private func window(forGlobal point: CGPoint) -> OverlayWindow? {
        windows.first { $0.frame.contains(point) }
    }

    func rootLayer(forGlobal point: CGPoint) -> (layer: CALayer, frame: CGRect)? {
        guard let w = window(forGlobal: point), let layer = w.contentView?.layer else { return nil }
        return (layer, w.frame)
    }
}
```

- [ ] **Step 3: `EffectCoordinator.swift` 골격 구현**

```swift
import AppKit

final class EffectCoordinator {
    private let controller: OverlayWindowController
    private let store: SettingsStore

    init(controller: OverlayWindowController, store: SettingsStore) {
        self.controller = controller
        self.store = store
    }

    func handleMove(global: CGPoint) {
        guard let (layer, frame) = controller.rootLayer(forGlobal: global) else { return }
        let p = CoordinateConverter.toLayerPoint(globalPoint: global, in: frame)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        broadcastMove(point: p, root: layer)
        CATransaction.commit()
    }

    func handleClick(global: CGPoint, kind: ClickKind) {
        guard let (layer, frame) = controller.rootLayer(forGlobal: global) else { return }
        let p = CoordinateConverter.toLayerPoint(globalPoint: global, in: frame)
        broadcastClick(point: p, kind: kind, root: layer)
    }

    // Task 6~9에서 실제 효과 레이어 연결
    private func broadcastMove(point: CGPoint, root: CALayer) {}
    private func broadcastClick(point: CGPoint, kind: ClickKind, root: CALayer) {}
}
```

- [ ] **Step 4: `AppDelegate` 배선**

```swift
private let store = SettingsStore()
private lazy var overlayController = OverlayWindowController()
private lazy var coordinator = EffectCoordinator(controller: overlayController, store: store)
```
`applicationDidFinishLaunching`에서 `eventMonitor.onMove/onClick`을 `coordinator.handleMove/handleClick`으로 연결하고, `NSApplication.didChangeScreenParametersNotification` 관찰 시 `overlayController.rebuildForCurrentScreens()` 호출.

- [ ] **Step 5: 빌드 검증**

Run: `./scripts/build_app.sh`
Expected: 컴파일 성공. 실행 시 화면별 투명 창이 생성되고(아직 아무것도 안 보임) 클릭이 통과되는지(뒤 앱이 정상 클릭됨) 확인.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: transparent click-through overlay windows + effect coordinator skeleton"
```

---

### Task 6: 커서 하이라이트 레이어

**Files:**
- Create: `Sources/HighlightCursor/Effects/HighlightLayer.swift`
- Create: `Sources/HighlightCursor/Support/ColorHex.swift`
- Modify: `Sources/HighlightCursor/Overlay/EffectCoordinator.swift`
- Test: `Tests/HighlightCursorTests/ColorHexTests.swift`

**Interfaces:**
- Consumes: `EffectCoordinator.broadcastMove`(Task 5), `Settings`(Task 2).
- Produces:
  - `enum ColorHex { static func cgColor(_ hex: String, alpha: Double) -> CGColor }` — "#RRGGBB" 파싱, 실패 시 노란색 반환.
  - `final class HighlightLayer` — `init(settings: Settings)`, `let layer: CAShapeLayer`, `func move(to point: CGPoint)`(레이어 position 갱신), `func apply(settings: Settings)`(지름/색/투명도 반영). 원은 `CAShapeLayer`의 원형 path + `fillColor` + 은은한 `shadow`(글로우).

- [ ] **Step 1: 실패하는 `ColorHexTests` 작성**

```swift
import XCTest
@testable import HighlightCursor

final class ColorHexTests: XCTestCase {
    func test_parsesValidHex() {
        let c = ColorHex.cgColor("#FF0000", alpha: 1.0)
        let comps = c.components ?? []
        XCTAssertEqual(comps[0], 1.0, accuracy: 0.01)
        XCTAssertEqual(comps[1], 0.0, accuracy: 0.01)
        XCTAssertEqual(comps[2], 0.0, accuracy: 0.01)
    }
    func test_fallsBackOnInvalid() {
        let c = ColorHex.cgColor("nope", alpha: 1.0)
        XCTAssertNotNil(c.components)
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `swift test --filter ColorHexTests`
Expected: FAIL.

- [ ] **Step 3: `ColorHex.swift` 구현**

```swift
import CoreGraphics

enum ColorHex {
    static func cgColor(_ hex: String, alpha: Double) -> CGColor {
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
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `swift test --filter ColorHexTests`
Expected: PASS.

- [ ] **Step 5: `HighlightLayer.swift` 구현**

```swift
import QuartzCore

final class HighlightLayer {
    let layer = CAShapeLayer()
    private var diameter: Double = 50

    init(settings: Settings) { apply(settings: settings) }

    func apply(settings: Settings) {
        diameter = settings.highlightDiameter
        let d = diameter
        layer.frame = CGRect(x: 0, y: 0, width: d, height: d)
        layer.path = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: d, height: d), transform: nil)
        layer.fillColor = ColorHex.cgColor(settings.highlightColorHex, alpha: settings.highlightOpacity)
        layer.shadowColor = ColorHex.cgColor(settings.highlightColorHex, alpha: 1.0)
        layer.shadowRadius = 8
        layer.shadowOpacity = 0.6
        layer.shadowOffset = .zero
    }

    func move(to point: CGPoint) {
        layer.position = point   // anchorPoint 기본 0.5,0.5 → 중심 정렬
    }
}
```

- [ ] **Step 6: `EffectCoordinator`에 하이라이트 연결**

`EffectCoordinator`에 `private var highlight: HighlightLayer?` 추가. `broadcastMove`에서 설정이 켜져 있으면 현재 root layer에 highlight.layer를 addSublayer(한 번만), `highlight.move(to: point)` 호출. 꺼져 있으면 `highlight.layer.removeFromSuperlayer()`.

- [ ] **Step 7: 빌드 + 실제 실행 검증**

Run: `./scripts/build_app.sh && open HighlightCursor.app`
마우스를 따라 노란 반투명 원이 부드럽게 따라오는지, 멀티 모니터 경계를 넘을 때 반대 화면에서 이어지는지 확인.

- [ ] **Step 8: Commit**

```bash
git add -A && git commit -m "feat: cursor highlight layer with hex color parsing"
```

---

### Task 7: 클릭 이펙트 레이어

**Files:**
- Create: `Sources/HighlightCursor/Effects/ClickEffectLayer.swift`
- Modify: `Sources/HighlightCursor/Overlay/EffectCoordinator.swift`

**Interfaces:**
- Consumes: `EffectCoordinator.broadcastClick`(Task 5), `ColorHex`(Task 6).
- Produces: `final class ClickEffectLayer { func emit(at point: CGPoint, kind: ClickKind, on root: CALayer) }` — 클릭 위치에 일회성 링 `CAShapeLayer`를 만들고 scale(0.2→1.4) + opacity(0.8→0) `CAAnimationGroup`(0.4s)을 붙여 애니메이션 종료 시 `removeFromSuperlayer`. 좌클릭/우클릭 색 구분. `CATransaction.setCompletionBlock`으로 제거.

- [ ] **Step 1: `ClickEffectLayer.swift` 구현**

```swift
import QuartzCore

final class ClickEffectLayer {
    func emit(at point: CGPoint, kind: ClickKind, on root: CALayer) {
        let size: CGFloat = 40
        let ring = CAShapeLayer()
        ring.frame = CGRect(x: 0, y: 0, width: size, height: size)
        ring.position = point
        ring.path = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: size, height: size), transform: nil)
        ring.fillColor = nil
        ring.lineWidth = 3
        ring.strokeColor = kind == .left
            ? ColorHex.cgColor("#22D3EE", alpha: 0.9)
            : ColorHex.cgColor("#FF8800", alpha: 0.9)
        root.addSublayer(ring)

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.2; scale.toValue = 1.4
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.8; fade.toValue = 0.0
        let group = CAAnimationGroup()
        group.animations = [scale, fade]
        group.duration = 0.4
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)

        CATransaction.begin()
        CATransaction.setCompletionBlock { ring.removeFromSuperlayer() }
        ring.opacity = 0
        ring.add(group, forKey: "click")
        CATransaction.commit()
    }
}
```

- [ ] **Step 2: `EffectCoordinator`에 연결**

`broadcastClick`에서 `store.settings.clickEffectEnabled`가 true면 `clickEffect.emit(at: point, kind: kind, on: root)` 호출.

- [ ] **Step 3: 빌드 + 실제 실행 검증**

Run: `./scripts/build_app.sh && open HighlightCursor.app`
좌클릭 시 청록 링, 우클릭 시 주황 링이 퍼지며 사라지는지, 잔여 레이어가 쌓이지 않는지(메모리) 확인.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: click ripple effect (left/right color-coded)"
```

---

### Task 8: 스포트라이트 레이어

**Files:**
- Create: `Sources/HighlightCursor/Effects/SpotlightLayer.swift`
- Modify: `Sources/HighlightCursor/Overlay/EffectCoordinator.swift`

**Interfaces:**
- Consumes: `EffectCoordinator.broadcastMove`(Task 5), `Settings`(Task 2).
- Produces: `final class SpotlightLayer { init(settings: Settings, screenSize: CGSize); let layer: CALayer; func move(to point: CGPoint); func apply(settings: Settings, screenSize: CGSize) }` — 화면 크기의 어둠 레이어(`backgroundColor` 검정 + `settings.spotlightDimming` alpha)에 원형 구멍을 `mask`로 뚫는다. 마스크는 반경 `spotlightRadius`의 원(밝은 부분)을 제외한 영역만 불투명. 이동 시 마스크 레이어의 position만 갱신(전체 재렌더 금지).

- [ ] **Step 1: `SpotlightLayer.swift` 구현**

```swift
import QuartzCore

final class SpotlightLayer {
    let layer = CALayer()
    private let hole = CAShapeLayer()
    private let maskLayer = CALayer()
    private var radius: CGFloat = 150

    init(settings: Settings, screenSize: CGSize) { apply(settings: settings, screenSize: screenSize) }

    func apply(settings: Settings, screenSize: CGSize) {
        radius = CGFloat(settings.spotlightRadius)
        layer.frame = CGRect(origin: .zero, size: screenSize)
        layer.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: settings.spotlightDimming)

        // 마스크: 전체 불투명(fill)에서 원만 뚫음(evenOdd)
        maskLayer.frame = layer.bounds
        let path = CGMutablePath()
        path.addRect(layer.bounds)
        hole.frame = layer.bounds
        hole.fillRule = .evenOdd
        hole.fillColor = CGColor(gray: 0, alpha: 1)
        rebuildHole(at: CGPoint(x: screenSize.width/2, y: screenSize.height/2))
        maskLayer.addSublayer(hole)
        layer.mask = maskLayer
    }

    private func rebuildHole(at point: CGPoint) {
        let full = CGMutablePath()
        full.addRect(hole.bounds)
        full.addEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius*2, height: radius*2))
        hole.path = full   // evenOdd → 사각형 내부이면서 원 외부만 채워짐(=어둡게)
    }

    func move(to point: CGPoint) {
        rebuildHole(at: point)
    }
}
```

- [ ] **Step 2: `EffectCoordinator`에 연결**

`broadcastMove`에서 `store.settings.spotlightEnabled`면 root에 `spotlight.layer` 삽입(맨 아래, highlight보다 뒤) 후 `spotlight.move(to: point)`. 꺼지면 `spotlight.layer.removeFromSuperlayer()`. 스포트라이트 레이어는 highlight/click보다 zPosition을 낮게.

- [ ] **Step 3: 빌드 + 실제 실행 검증**

Run: `./scripts/build_app.sh && open HighlightCursor.app`
설정에서 spotlight를 켠 상태로 실행(임시로 `Settings.default`의 spotlightEnabled를 true로 두고 테스트, 검증 후 원복). 커서 주변만 밝고 나머지가 50% 어두워지는지, 이동 시 구멍이 따라오는지, 클릭은 여전히 통과되는지 확인.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: spotlight dimming layer with moving circular hole mask"
```

---

### Task 9: 커서 트레일 레이어

**Files:**
- Create: `Sources/HighlightCursor/Effects/TrailLayer.swift`
- Modify: `Sources/HighlightCursor/Overlay/EffectCoordinator.swift`

**Interfaces:**
- Consumes: `EffectCoordinator.broadcastMove`(Task 5), `Settings`(Task 2), `ColorHex`(Task 6).
- Produces: `final class TrailLayer { init(settings: Settings); func addPoint(_ point: CGPoint, on root: CALayer) }` — 이동 시 작은 점 레이어를 남기고 fade-out(0.5s) 후 제거. 활성 잔상 개수를 `settings.trailMaxCount`로 제한(초과 시 가장 오래된 것 즉시 제거). 내부에 `private var dots: [CALayer]` 큐 유지.

- [ ] **Step 1: `TrailLayer.swift` 구현**

```swift
import QuartzCore

final class TrailLayer {
    private var dots: [CALayer] = []
    private var maxCount: Int
    private var colorHex: String
    private var opacity: Double

    init(settings: Settings) {
        maxCount = settings.trailMaxCount
        colorHex = settings.highlightColorHex
        opacity = settings.highlightOpacity
    }

    func apply(settings: Settings) {
        maxCount = settings.trailMaxCount
        colorHex = settings.highlightColorHex
        opacity = settings.highlightOpacity
    }

    func addPoint(_ point: CGPoint, on root: CALayer) {
        let size: CGFloat = 12
        let dot = CALayer()
        dot.frame = CGRect(x: 0, y: 0, width: size, height: size)
        dot.cornerRadius = size / 2
        dot.position = point
        dot.backgroundColor = ColorHex.cgColor(colorHex, alpha: opacity)
        root.addSublayer(dot)
        dots.append(dot)

        while dots.count > maxCount { dots.removeFirst().removeFromSuperlayer() }

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = opacity; fade.toValue = 0.0
        fade.duration = 0.5
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self, weak dot] in
            guard let dot else { return }
            dot.removeFromSuperlayer()
            self?.dots.removeAll { $0 === dot }
        }
        dot.opacity = 0
        dot.add(fade, forKey: "trail")
        CATransaction.commit()
    }
}
```

- [ ] **Step 2: `EffectCoordinator`에 연결**

`broadcastMove`에서 `store.settings.trailEnabled`면 `trail.addPoint(point, on: root)` 호출.

- [ ] **Step 3: 빌드 + 실제 실행 검증**

Run: `./scripts/build_app.sh && open HighlightCursor.app`
트레일을 켠 상태로 빠르게 움직일 때 잔상이 최대 8개 이내로 유지되며 사라지는지, 무한 증가하지 않는지 확인.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: cursor trail with bounded dot queue"
```

---

### Task 10: 메뉴바 컨트롤러 + 효과 토글

**Files:**
- Create: `Sources/HighlightCursor/MenuBarController.swift`
- Modify: `Sources/HighlightCursor/AppDelegate.swift`
- Modify: `Sources/HighlightCursor/Overlay/EffectCoordinator.swift`

**Interfaces:**
- Consumes: `SettingsStore`(Task 2), `EffectCoordinator`(Task 5).
- Produces: `final class MenuBarController { init(store: SettingsStore, onSettingsChanged: @escaping () -> Void); }` — `NSStatusItem`(system symbol 아이콘) + `NSMenu`. 항목: 하이라이트/스포트라이트/트레일/클릭이펙트 각 토글(체크마크), 설정 열기, 종료. 토글 시 `store.settings` 갱신 후 `onSettingsChanged()` 호출.
- `EffectCoordinator`에 `func refreshSettings()` 추가 — 각 효과 레이어에 `apply(settings:)` 재적용, 꺼진 효과 레이어 제거.

- [ ] **Step 1: `MenuBarController.swift` 구현**

```swift
import AppKit

final class MenuBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let store: SettingsStore
    private let onChange: () -> Void

    init(store: SettingsStore, onSettingsChanged: @escaping () -> Void) {
        self.store = store
        self.onChange = onSettingsChanged
        statusItem.button?.image = NSImage(systemSymbolName: "cursorarrow.rays", accessibilityDescription: "Highlight Cursor")
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let s = store.settings
        menu.addItem(toggle("Highlight", s.highlightEnabled, #selector(toggleHighlight)))
        menu.addItem(toggle("Spotlight", s.spotlightEnabled, #selector(toggleSpotlight)))
        menu.addItem(toggle("Trail", s.trailEnabled, #selector(toggleTrail)))
        menu.addItem(toggle("Click Effect", s.clickEffectEnabled, #selector(toggleClick)))
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.items.forEach { $0.target = ($0.action == #selector(NSApplication.terminate(_:))) ? nil : self }
        statusItem.menu = menu
    }

    private func toggle(_ title: String, _ on: Bool, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.state = on ? .on : .off
        return item
    }

    @objc private func toggleHighlight() { var s = store.settings; s.highlightEnabled.toggle(); store.settings = s; changed() }
    @objc private func toggleSpotlight() { var s = store.settings; s.spotlightEnabled.toggle(); store.settings = s; changed() }
    @objc private func toggleTrail() { var s = store.settings; s.trailEnabled.toggle(); store.settings = s; changed() }
    @objc private func toggleClick() { var s = store.settings; s.clickEffectEnabled.toggle(); store.settings = s; changed() }
    private func changed() { rebuildMenu(); onChange() }
}
```

- [ ] **Step 2: `AppDelegate`에 배선 + `EffectCoordinator.refreshSettings()` 구현**

`AppDelegate`에 `private lazy var menuBar = MenuBarController(store: store) { [weak self] in self?.coordinator.refreshSettings() }` 추가하고 launch 시 참조 유지. `EffectCoordinator.refreshSettings()`는 각 효과 레이어에 최신 settings를 apply하고 꺼진 효과는 removeFromSuperlayer.

- [ ] **Step 3: 빌드 + 실제 실행 검증**

Run: `./scripts/build_app.sh && open HighlightCursor.app`
메뉴바 아이콘에서 각 효과를 켜고 끌 때 즉시 반영되는지, 체크마크가 상태를 반영하는지 확인.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: menu-bar controller with per-effect toggles"
```

---

### Task 11: 전역 단축키

**Files:**
- Create: `Sources/HighlightCursor/Shortcuts/HotkeyManager.swift`
- Modify: `Sources/HighlightCursor/AppDelegate.swift`

**Interfaces:**
- Consumes: `SettingsStore`(Task 2), 토글 콜백(Task 10).
- Produces: `final class HotkeyManager { var onToggleHighlight: (() -> Void)?; var onToggleSpotlight: (() -> Void)?; var onToggleTrail: (() -> Void)?; func start() }` — `NSEvent.addGlobalMonitorForEvents(matching: .keyDown)`로 `⌥⌘H`/`⌥⌘S`/`⌥⌘T` 조합을 감지(modifierFlags에 `.option`,`.command` 포함 + keyCode 매칭). 각각 콜백 호출.

- [ ] **Step 1: `HotkeyManager.swift` 구현**

```swift
import AppKit

final class HotkeyManager {
    var onToggleHighlight: (() -> Void)?
    var onToggleSpotlight: (() -> Void)?
    var onToggleTrail: (() -> Void)?
    private var monitor: Any?

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags.contains(.option), flags.contains(.command) else { return }
            switch event.keyCode {
            case 4:  self?.onToggleHighlight?()  // H
            case 1:  self?.onToggleSpotlight?()  // S
            case 17: self?.onToggleTrail?()      // T
            default: break
            }
        }
    }
}
```

- [ ] **Step 2: `AppDelegate`에 배선**

`HotkeyManager` 인스턴스를 만들고 콜백을 Task 10의 토글 로직(설정 갱신 + `coordinator.refreshSettings()` + 메뉴 재구성)에 연결한 뒤 `start()`. 토글 로직을 `MenuBarController`와 공유하도록 `AppDelegate`에 공용 `toggle(_ keyPath:)` 헬퍼를 두는 것을 권장.

- [ ] **Step 3: 빌드 + 실제 실행 검증**

Run: `./scripts/build_app.sh && open HighlightCursor.app`
⌥⌘H/⌥⌘S/⌥⌘T로 각 효과가 토글되고 메뉴바 체크마크도 동기화되는지 확인.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: global hotkeys for effect toggles"
```

---

### Task 12: 설정 창 (AppKit)

**Files:**
- Create: `Sources/HighlightCursor/Settings/SettingsWindow.swift`
- Modify: `Sources/HighlightCursor/MenuBarController.swift`

**Interfaces:**
- Consumes: `SettingsStore`(Task 2), 변경 콜백(Task 10).
- Produces: `final class SettingsWindowController: NSWindowController { init(store: SettingsStore, onChange: @escaping () -> Void); func show() }` — 하이라이트 지름 슬라이더, 색상 well(`NSColorWell`), 투명도 슬라이더, 스포트라이트 반경/어둡기 슬라이더, 트레일 개수 스테퍼. 값 변경 시 `store.settings` 갱신 + `onChange()`. 메뉴바 "Settings…" 항목에서 `show()` 호출.

- [ ] **Step 1: `SettingsWindow.swift` 구현 (슬라이더/컬러웰 폼)**

핵심 골격:
```swift
import AppKit

final class SettingsWindowController: NSWindowController {
    private let store: SettingsStore
    private let onChange: () -> Void

    init(store: SettingsStore, onChange: @escaping () -> Void) {
        self.store = store
        self.onChange = onChange
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 300),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Highlight Cursor 설정"
        super.init(window: window)
        buildForm()
    }
    required init?(coder: NSCoder) { fatalError() }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.center()
    }

    private func buildForm() {
        // NSStackView에 라벨+슬라이더/컬러웰/스테퍼 행을 쌓고
        // 각 컨트롤의 target/action에서 store.settings의 해당 필드 갱신 후 onChange() 호출.
        // (지름 20~120, 투명도 0.1~1.0, 반경 60~400, 어둡기 0.2~0.9, 트레일 개수 3~20)
    }
}
```

- [ ] **Step 2: 메뉴바 "Settings…" 항목 추가**

`MenuBarController`에 "Settings…" 메뉴 항목과 `SettingsWindowController` 소유·`show()` 연결.

- [ ] **Step 3: 빌드 + 실제 실행 검증**

Run: `./scripts/build_app.sh && open HighlightCursor.app`
설정 창에서 지름/색/투명도/반경/어둡기/트레일 개수를 바꾸면 즉시 효과에 반영되고, 재실행 후에도 값이 유지되는지(UserDefaults) 확인.

- [ ] **Step 4: 전체 테스트 통과 확인**

Run: `swift test`
Expected: 모든 단위 테스트 PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: settings window (sliders/color well) wired to live effects"
```

---

### Task 13: 최적화 검증 + 마감

**Files:**
- Create: `README.md`
- Modify: 필요 시 성능 이슈 발견 지점

**Interfaces:**
- Consumes: 전체 앱.

- [ ] **Step 1: CPU 사용량 측정**

앱 실행 후 `top -pid $(pgrep HighlightCursor) -l 5 -stats pid,cpu,mem` 로 측정.
Expected: 마우스 활발히 이동 시 CPU 한 자릿수 %, 정지 시 ~0%. 초과 시 원인(불필요한 재렌더, 폴링) 추적.

- [ ] **Step 2: 마우스 정지 시 콜백 0 확인**

Console 로그로 정지 상태에서 move 콜백이 발생하지 않음을 확인(폴링 없음 검증).

- [ ] **Step 3: `README.md` 작성 (readme 스킬 활용, 완성도 높게)**

`readme` 스킬(`/Users/jesamkim/.kiro/crew/skills/readme/SKILL.md` 또는 imported 버전)을 읽고 그 형식에 맞춰 **제대로 멋지게** 작성한다. 최소 포함 내용:
- 상단: 프로젝트 제목 + 한 줄 소개 + (가능하면) 데모 GIF/스크린샷 자리
- 기능 목록(하이라이트/클릭 이펙트/스포트라이트/트레일/단축키)을 시각적으로 정리
- 요구 환경(macOS 14+, Swift, CLT), 빌드·실행 방법(`./scripts/build_app.sh`, 접근성 권한 부여 절차)
- 단축키 표(⌥⌘H/⌥⌘S/⌥⌘T)와 설정 항목 설명
- 리소스 최적화 설계 요약(이벤트 기반·GPU 렌더·꺼진 효과 레이어 제거)
- 테스트 실행법(`./scripts/test.sh`, XCTest 부재 배경 한 줄)
사용자 요청: 완성 단계에서 README를 대충 넘기지 말고 스킬 기준으로 다듬을 것.

- [ ] **Step 4: 전체 회귀 확인 + Codex 최종 리뷰**

Run: `swift test && ./scripts/build_app.sh`
그리고 orca-cli를 통한 Codex GPT-5.6(Terra) 전체 브랜치 리뷰 실행, critical/high 반영.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "docs: README + optimization verification"
```
