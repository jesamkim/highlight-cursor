import AppKit
import HighlightCursorCore

/// 메뉴바(상단 상태바) 아이콘과 메뉴를 담당한다.
/// 각 효과를 켜고 끄는 체크마크 토글과 종료 메뉴를 제공한다.
/// 토글하면 `SettingsStore`를 갱신하고 `onSettingsChanged`로 코디네이터에 반영을 알린다.
@MainActor
final class MenuBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let store: SettingsStore
    private let onChange: () -> Void

    init(store: SettingsStore, onSettingsChanged: @escaping () -> Void) {
        self.store = store
        self.onChange = onSettingsChanged
        statusItem.button?.image = NSImage(
            systemSymbolName: "cursorarrow.rays",
            accessibilityDescription: "Highlight Cursor"
        )
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false   // isEnabled를 수동 제어(미구현 효과 비활성화)
        let s = store.settings
        // 하이라이트는 구현됨(enabled). 나머지 효과는 아직 미구현이라 "(준비 중)"으로
        // 비활성화해 동작하지 않는 토글을 눌러 혼란이 생기지 않게 한다.
        // Task 7/8/9에서 각 효과가 구현되면 enabled=true로 살린다.
        menu.addItem(toggleItem("하이라이트", isOn: s.highlightEnabled,
                                action: #selector(toggleHighlight), enabled: true))
        menu.addItem(toggleItem("스포트라이트 (준비 중)", isOn: s.spotlightEnabled,
                                action: #selector(toggleSpotlight), enabled: false))
        menu.addItem(toggleItem("트레일 (준비 중)", isOn: s.trailEnabled,
                                action: #selector(toggleTrail), enabled: false))
        menu.addItem(toggleItem("클릭 이펙트 (준비 중)", isOn: s.clickEffectEnabled,
                                action: #selector(toggleClick), enabled: false))
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = nil   // responder chain → NSApp
        menu.addItem(quit)

        // 종료 항목을 제외한 토글 항목의 타깃을 self로 설정한다.
        for item in menu.items where item.action != nil && item.action != #selector(NSApplication.terminate(_:)) {
            item.target = self
        }
        statusItem.menu = menu
    }

    private func toggleItem(_ title: String, isOn: Bool, action: Selector, enabled: Bool) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.state = isOn ? .on : .off
        item.isEnabled = enabled
        return item
    }

    @objc private func toggleHighlight() {
        var s = store.settings; s.highlightEnabled.toggle(); store.settings = s; changed()
    }
    @objc private func toggleSpotlight() {
        var s = store.settings; s.spotlightEnabled.toggle(); store.settings = s; changed()
    }
    @objc private func toggleTrail() {
        var s = store.settings; s.trailEnabled.toggle(); store.settings = s; changed()
    }
    @objc private func toggleClick() {
        var s = store.settings; s.clickEffectEnabled.toggle(); store.settings = s; changed()
    }

    private func changed() {
        rebuildMenu()   // 체크마크 상태 갱신
        onChange()
    }
}
