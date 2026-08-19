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
        // 하이라이트·스포트라이트·클릭 이펙트·트레일 모두 구현됨.
        menu.addItem(toggleItem("하이라이트", isOn: s.highlightEnabled,
                                action: #selector(toggleHighlight), enabled: true))
        menu.addItem(toggleItem("스포트라이트", isOn: s.spotlightEnabled,
                                action: #selector(toggleSpotlight), enabled: true))
        menu.addItem(toggleItem("트레일", isOn: s.trailEnabled,
                                action: #selector(toggleTrail), enabled: true))
        menu.addItem(toggleItem("클릭 이펙트", isOn: s.clickEffectEnabled,
                                action: #selector(toggleClick), enabled: true))
        menu.addItem(clickStyleMenuItem(current: s.clickEffectStyle))
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

    /// 한국어 라벨: ripple=물결, sakura=벚꽃, energyBurst=기 폭발, sparkle=반짝임.
    private func styleLabel(_ style: ClickEffectStyle) -> String {
        switch style {
        case .ripple:      return "물결"
        case .sakura:      return "벚꽃"
        case .energyBurst: return "기 폭발"
        case .sparkle:     return "반짝임"
        }
    }

    /// "클릭 이펙트 스타일 ▸" 서브메뉴. 4개 스타일을 라디오 체크로 제공하고
    /// 현재 선택된 스타일에 체크마크를 표시한다.
    private func clickStyleMenuItem(current: ClickEffectStyle) -> NSMenuItem {
        let parent = NSMenuItem(title: "클릭 이펙트 스타일", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        for style in ClickEffectStyle.allCases {
            let item = NSMenuItem(title: styleLabel(style),
                                  action: #selector(selectClickStyle(_:)), keyEquivalent: "")
            item.state = (style == current) ? .on : .off
            item.target = self
            item.representedObject = style.rawValue
            submenu.addItem(item)
        }
        parent.submenu = submenu
        return parent
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

    @objc private func selectClickStyle(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let style = ClickEffectStyle(rawValue: raw) else { return }
        var s = store.settings; s.clickEffectStyle = style; store.settings = s; changed()
    }

    private func changed() {
        rebuildMenu()   // 체크마크 상태 갱신
        onChange()
    }
}
