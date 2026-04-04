import AppKit

struct PreferencesViewState {
    var showColors: Bool
    var showPaceAlert: Bool
    var showLastUpdated: Bool
    var launchAtLogin: Bool
    var weeklyPacingMode: WeeklyPacingMode
}

final class PreferencesWindowController: NSWindowController {
    var onToggleShowColors: ((Bool) -> Void)?
    var onToggleShowPaceAlert: ((Bool) -> Void)?
    var onToggleShowLastUpdated: ((Bool) -> Void)?
    var onToggleLaunchAtLogin: ((Bool) -> Void)?
    var onSelectWeeklyPacingMode: ((WeeklyPacingMode) -> Void)?

    private let showColorsButton = NSButton(checkboxWithTitle: "Show colors in menu and status bar", target: nil, action: nil)
    private let showPaceAlertButton = NSButton(checkboxWithTitle: "Show pace alerts", target: nil, action: nil)
    private let showLastUpdatedButton = NSButton(checkboxWithTitle: "Show last updated", target: nil, action: nil)
    private let launchAtLoginButton = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)

    private let standardPaceButton = NSButton(radioButtonWithTitle: WeeklyPacingMode.workWeek40.menuTitle, target: nil, action: nil)
    private let balancedPaceButton = NSButton(radioButtonWithTitle: WeeklyPacingMode.balanced56.menuTitle, target: nil, action: nil)
    private let heavyPaceButton = NSButton(radioButtonWithTitle: WeeklyPacingMode.heavy70.menuTitle, target: nil, action: nil)
    private let weeklyExplanationLabel = NSTextField(labelWithString: "")

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 468, height: 420),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Codex Quota Peek Preferences"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        setup()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func update(with state: PreferencesViewState) {
        showColorsButton.state = state.showColors ? .on : .off
        showPaceAlertButton.state = state.showPaceAlert ? .on : .off
        showLastUpdatedButton.state = state.showLastUpdated ? .on : .off
        launchAtLoginButton.state = state.launchAtLogin ? .on : .off

        standardPaceButton.state = state.weeklyPacingMode == .workWeek40 ? .on : .off
        balancedPaceButton.state = state.weeklyPacingMode == .balanced56 ? .on : .off
        heavyPaceButton.state = state.weeklyPacingMode == .heavy70 ? .on : .off
        weeklyExplanationLabel.stringValue = QuotaDisplayPolicy.weeklyPaceExplanation(for: state.weeklyPacingMode)
    }

    private func setup() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 18
        root.edgeInsets = NSEdgeInsets(top: 22, left: 22, bottom: 22, right: 22)
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            root.topAnchor.constraint(equalTo: contentView.topAnchor),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        root.addArrangedSubview(sectionView(
            title: "Display",
            description: "Control what metadata is visible in the menu bar and dropdown.",
            controls: [
                configureCheckbox(showColorsButton, action: #selector(toggleShowColors(_:))),
                configureCheckbox(showPaceAlertButton, action: #selector(toggleShowPaceAlert(_:))),
                configureCheckbox(showLastUpdatedButton, action: #selector(toggleShowLastUpdated(_:)))
            ]
        ))

        weeklyExplanationLabel.font = NSFont.systemFont(ofSize: 11)
        weeklyExplanationLabel.textColor = .secondaryLabelColor
        weeklyExplanationLabel.lineBreakMode = .byWordWrapping
        weeklyExplanationLabel.maximumNumberOfLines = 0

        root.addArrangedSubview(sectionView(
            title: QuotaDisplayPolicy.weeklyPacingSectionTitle,
            description: "\(QuotaDisplayPolicy.weeklyPacingHintTitle) \(QuotaDisplayPolicy.weeklyPacingHintDetail)",
            controls: [
                configureRadio(standardPaceButton, action: #selector(selectWeeklyPacing(_:))),
                configureRadio(balancedPaceButton, action: #selector(selectWeeklyPacing(_:))),
                configureRadio(heavyPaceButton, action: #selector(selectWeeklyPacing(_:))),
                weeklyExplanationLabel
            ]
        ))

        root.addArrangedSubview(sectionView(
            title: "App",
            description: "Daily behavior and startup options.",
            controls: [
                configureCheckbox(launchAtLoginButton, action: #selector(toggleLaunchAtLogin(_:)))
            ]
        ))
    }

    private func sectionView(title: String, description: String, controls: [NSView]) -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 10

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .labelColor

        let descriptionLabel = NSTextField(wrappingLabelWithString: description)
        descriptionLabel.font = NSFont.systemFont(ofSize: 11)
        descriptionLabel.textColor = .secondaryLabelColor

        container.addArrangedSubview(titleLabel)
        container.addArrangedSubview(descriptionLabel)
        controls.forEach { container.addArrangedSubview($0) }
        return container
    }

    private func configureCheckbox(_ button: NSButton, action: Selector) -> NSButton {
        button.target = self
        button.action = action
        button.font = NSFont.systemFont(ofSize: 12)
        return button
    }

    private func configureRadio(_ button: NSButton, action: Selector) -> NSButton {
        button.target = self
        button.action = action
        button.font = NSFont.systemFont(ofSize: 12)
        return button
    }

    @objc
    private func toggleShowColors(_ sender: NSButton) {
        onToggleShowColors?(sender.state == .on)
    }

    @objc
    private func toggleShowPaceAlert(_ sender: NSButton) {
        onToggleShowPaceAlert?(sender.state == .on)
    }

    @objc
    private func toggleShowLastUpdated(_ sender: NSButton) {
        onToggleShowLastUpdated?(sender.state == .on)
    }

    @objc
    private func toggleLaunchAtLogin(_ sender: NSButton) {
        onToggleLaunchAtLogin?(sender.state == .on)
    }

    @objc
    private func selectWeeklyPacing(_ sender: NSButton) {
        if sender === standardPaceButton {
            onSelectWeeklyPacingMode?(.workWeek40)
        } else if sender === heavyPaceButton {
            onSelectWeeklyPacingMode?(.heavy70)
        } else {
            onSelectWeeklyPacingMode?(.balanced56)
        }
    }
}
