import AppKit
import HighlightCursorCore

/// 하이라이트/스포트라이트/트레일 세부값과 로그인 시 자동 실행을 조정하는 설정 창.
/// 각 컨트롤 변경 시 즉시 `store.settings`를 갱신하고 `onChange()`를 호출해
/// 살아있는 효과에 반영한다(재빌드나 재실행 불필요).
@MainActor
final class SettingsWindowController: NSWindowController {
    private let store: SettingsStore
    private let onChange: () -> Void

    // 값 표시 라벨(슬라이더 옆 숫자)
    private let diameterValueLabel = NSTextField(labelWithString: "")
    private let opacityValueLabel = NSTextField(labelWithString: "")
    private let radiusValueLabel = NSTextField(labelWithString: "")
    private let dimmingValueLabel = NSTextField(labelWithString: "")
    private let trailCountValueLabel = NSTextField(labelWithString: "")

    init(store: SettingsStore, onChange: @escaping () -> Void) {
        self.store = store
        self.onChange = onChange
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 460),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Highlight Cursor 설정"
        super.init(window: window)
        buildForm()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.center()
    }

    // MARK: - Form

    private func buildForm() {
        let s = store.settings
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(sectionLabel("하이라이트"))
        stack.addArrangedSubview(sliderRow(
            title: "지름", valueLabel: diameterValueLabel,
            min: 20, max: 120, value: s.highlightDiameter,
            action: #selector(diameterChanged), format: { "\(Int($0))px" }
        ))
        stack.addArrangedSubview(sliderRow(
            title: "투명도", valueLabel: opacityValueLabel,
            min: 0.1, max: 1.0, value: s.highlightOpacity,
            action: #selector(opacityChanged), format: { String(format: "%.0f%%", $0 * 100) }
        ))
        stack.addArrangedSubview(colorRow(title: "색상", hex: s.highlightColorHex, action: #selector(colorChanged)))

        stack.addArrangedSubview(sectionLabel("스포트라이트"))
        stack.addArrangedSubview(sliderRow(
            title: "반경", valueLabel: radiusValueLabel,
            min: 60, max: 400, value: s.spotlightRadius,
            action: #selector(radiusChanged), format: { "\(Int($0))px" }
        ))
        stack.addArrangedSubview(sliderRow(
            title: "어둡기", valueLabel: dimmingValueLabel,
            min: 0.2, max: 0.9, value: s.spotlightDimming,
            action: #selector(dimmingChanged), format: { String(format: "%.0f%%", $0 * 100) }
        ))

        stack.addArrangedSubview(sectionLabel("트레일"))
        stack.addArrangedSubview(sliderRow(
            title: "잔상 개수", valueLabel: trailCountValueLabel,
            min: 3, max: 20, value: Double(s.trailMaxCount),
            action: #selector(trailCountChanged), format: { "\(Int($0))개" }
        ))

        stack.addArrangedSubview(sectionLabel("시작"))
        let loginToggle = NSButton(checkboxWithTitle: "macOS 로그인 시 자동 실행",
                                   target: self, action: #selector(loginToggled))
        loginToggle.state = LaunchAtLogin.isEnabled() ? .on : .off
        stack.addArrangedSubview(loginToggle)

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 460))
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
        ])
        window?.contentView = contentView

        refreshLabels(s)
    }

    private func sectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .boldSystemFont(ofSize: 13)
        return label
    }

    private func sliderRow(
        title: String, valueLabel: NSTextField,
        min: Double, max: Double, value: Double,
        action: Selector, format: @escaping (Double) -> String
    ) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.widthAnchor.constraint(equalToConstant: 70).isActive = true

        let slider = NSSlider(value: value, minValue: min, maxValue: max, target: self, action: action)
        slider.widthAnchor.constraint(equalToConstant: 200).isActive = true

        valueLabel.widthAnchor.constraint(equalToConstant: 60).isActive = true
        valueLabel.stringValue = format(value)

        let row = NSStackView(views: [titleLabel, slider, valueLabel])
        row.orientation = .horizontal
        row.spacing = 8
        return row
    }

    private func colorRow(title: String, hex: String, action: Selector) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.widthAnchor.constraint(equalToConstant: 70).isActive = true

        let well = NSColorWell(frame: NSRect(x: 0, y: 0, width: 44, height: 24))
        well.color = ColorWellSupport.nsColor(fromHex: hex)
        well.target = self
        well.action = action

        let row = NSStackView(views: [titleLabel, well])
        row.orientation = .horizontal
        row.spacing = 8
        return row
    }

    private func refreshLabels(_ s: Settings) {
        diameterValueLabel.stringValue = "\(Int(s.highlightDiameter))px"
        opacityValueLabel.stringValue = String(format: "%.0f%%", s.highlightOpacity * 100)
        radiusValueLabel.stringValue = "\(Int(s.spotlightRadius))px"
        dimmingValueLabel.stringValue = String(format: "%.0f%%", s.spotlightDimming * 100)
        trailCountValueLabel.stringValue = "\(s.trailMaxCount)개"
    }

    // MARK: - Actions

    private func update(_ mutate: (inout Settings) -> Void) {
        var s = store.settings
        mutate(&s)
        store.settings = s
        refreshLabels(s)
        onChange()
    }

    @objc private func diameterChanged(_ sender: NSSlider) {
        update { $0.highlightDiameter = sender.doubleValue }
    }
    @objc private func opacityChanged(_ sender: NSSlider) {
        update { $0.highlightOpacity = sender.doubleValue }
    }
    @objc private func radiusChanged(_ sender: NSSlider) {
        update { $0.spotlightRadius = sender.doubleValue }
    }
    @objc private func dimmingChanged(_ sender: NSSlider) {
        update { $0.spotlightDimming = sender.doubleValue }
    }
    @objc private func trailCountChanged(_ sender: NSSlider) {
        update { $0.trailMaxCount = Int(sender.doubleValue) }
    }
    @objc private func colorChanged(_ sender: NSColorWell) {
        update { $0.highlightColorHex = ColorWellSupport.hexString(from: sender.color) }
    }
    @objc private func loginToggled(_ sender: NSButton) {
        let desired = sender.state == .on
        let succeeded = LaunchAtLogin.setEnabled(desired)
        if !succeeded {
            // 등록/해제가 실패하면 체크박스를 실제 상태로 되돌려
            // UI가 거짓 성공을 보여주지 않게 한다.
            sender.state = LaunchAtLogin.isEnabled() ? .on : .off
        }
    }
}
