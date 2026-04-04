import AppKit

struct PreferencesViewState {
    var showColors: Bool
    var showPaceAlert: Bool
    var showLastUpdated: Bool
    var launchAtLogin: Bool
    var weeklyPacingMode: WeeklyPacingMode
}

private final class FlippedContentView: NSView {
    override var isFlipped: Bool { true }
}

private final class CardView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.borderWidth = 1
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.65).cgColor
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.55).cgColor
    }

    required init?(coder: NSCoder) {
        return nil
    }
}

final class PreferencesWindowController: NSWindowController {
    var onToggleShowColors: ((Bool) -> Void)?
    var onToggleShowPaceAlert: ((Bool) -> Void)?
    var onToggleShowLastUpdated: ((Bool) -> Void)?
    var onToggleLaunchAtLogin: ((Bool) -> Void)?
    var onSelectWeeklyPacingMode: ((WeeklyPacingMode) -> Void)?

    private let showColorsButton = NSButton(checkboxWithTitle: "Show colors in menu and status bar", target: nil, action: nil)
    private let showPaceAlertButton = NSButton(checkboxWithTitle: "Show weekly pace alerts", target: nil, action: nil)
    private let showLastUpdatedButton = NSButton(checkboxWithTitle: "Show last updated labels", target: nil, action: nil)
    private let launchAtLoginButton = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)

    private let standardPaceButton = NSButton(radioButtonWithTitle: WeeklyPacingMode.workWeek40.menuTitle, target: nil, action: nil)
    private let balancedPaceButton = NSButton(radioButtonWithTitle: WeeklyPacingMode.balanced56.menuTitle, target: nil, action: nil)
    private let heavyPaceButton = NSButton(radioButtonWithTitle: WeeklyPacingMode.heavy70.menuTitle, target: nil, action: nil)

    private let weeklyExplanationLabel = NSTextField(wrappingLabelWithString: "")

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 560),
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

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        let documentView = FlippedContentView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView

        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 20
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            contentStack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 28),
            contentStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -28),
            contentStack.centerXAnchor.constraint(equalTo: documentView.centerXAnchor),
            contentStack.widthAnchor.constraint(lessThanOrEqualToConstant: 500),
            contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: documentView.leadingAnchor, constant: 28),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: documentView.trailingAnchor, constant: -28)
        ])

        contentStack.addArrangedSubview(makeHeader())
        contentStack.addArrangedSubview(makeDisplayCard())
        contentStack.addArrangedSubview(makeWeeklyPacingCard())
        contentStack.addArrangedSubview(makeAppCard())
    }

    private func makeHeader() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6

        let titleLabel = NSTextField(labelWithString: "Preferences")
        titleLabel.font = NSFont.systemFont(ofSize: 26, weight: .semibold)
        titleLabel.textColor = .labelColor

        let subtitleLabel = NSTextField(wrappingLabelWithString: "Tune what appears in the menu bar, how weekly pace warnings behave, and how the app starts.")
        subtitleLabel.font = NSFont.systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.maximumNumberOfLines = 0
        subtitleLabel.preferredMaxLayoutWidth = 500

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        return stack
    }

    private func makeDisplayCard() -> NSView {
        let rows = [
            optionRow(
                control: configureCheckbox(showColorsButton, action: #selector(toggleShowColors(_:))),
                detail: "Use green, yellow, and red to make remaining quota easier to scan."
            ),
            optionRow(
                control: configureCheckbox(showPaceAlertButton, action: #selector(toggleShowPaceAlert(_:))),
                detail: "Show inline weekly warnings when your usage is running ahead of your chosen pace."
            ),
            optionRow(
                control: configureCheckbox(showLastUpdatedButton, action: #selector(toggleShowLastUpdated(_:))),
                detail: "Show relative freshness labels like just updated, 12s, or 3m."
            )
        ]

        return sectionCard(
            title: "Display",
            description: "Control which metadata stays visible in the menu bar and dropdown.",
            body: verticalRows(rows, spacing: 14)
        )
    }

    private func makeWeeklyPacingCard() -> NSView {
        weeklyExplanationLabel.font = NSFont.systemFont(ofSize: 12)
        weeklyExplanationLabel.textColor = .secondaryLabelColor
        weeklyExplanationLabel.maximumNumberOfLines = 0
        weeklyExplanationLabel.preferredMaxLayoutWidth = 430

        let rows = [
            pacingRow(for: standardPaceButton, action: #selector(selectWeeklyPacing(_:)), summary: WeeklyPacingMode.workWeek40.summary),
            pacingRow(for: balancedPaceButton, action: #selector(selectWeeklyPacing(_:)), summary: WeeklyPacingMode.balanced56.summary),
            pacingRow(for: heavyPaceButton, action: #selector(selectWeeklyPacing(_:)), summary: WeeklyPacingMode.heavy70.summary),
            weeklyExplanationLabel
        ]

        return sectionCard(
            title: QuotaDisplayPolicy.weeklyPacingSectionTitle,
            description: "This setting only changes when the weekly ! warning appears. It never changes the actual % left value.",
            body: verticalRows(rows, spacing: 14)
        )
    }

    private func makeAppCard() -> NSView {
        let rows = [
            optionRow(
                control: configureCheckbox(launchAtLoginButton, action: #selector(toggleLaunchAtLogin(_:))),
                detail: "Start Codex Quota Peek automatically when you sign in to macOS."
            )
        ]

        return sectionCard(
            title: "App",
            description: "Daily startup behavior and launch preferences.",
            body: verticalRows(rows, spacing: 14)
        )
    }

    private func sectionCard(title: String, description: String, body: NSView) -> NSView {
        let card = CardView()
        card.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            card.widthAnchor.constraint(equalToConstant: 500)
        ])

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .labelColor

        let descriptionLabel = NSTextField(wrappingLabelWithString: description)
        descriptionLabel.font = NSFont.systemFont(ofSize: 12.5)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.maximumNumberOfLines = 0
        descriptionLabel.preferredMaxLayoutWidth = 430

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(descriptionLabel)
        stack.addArrangedSubview(body)
        return card
    }

    private func optionRow(control: NSButton, detail: String) -> NSView {
        let row = NSStackView()
        row.orientation = .vertical
        row.alignment = .leading
        row.spacing = 4

        let detailLabel = NSTextField(wrappingLabelWithString: detail)
        detailLabel.font = NSFont.systemFont(ofSize: 11.5)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.maximumNumberOfLines = 0
        detailLabel.preferredMaxLayoutWidth = 400

        row.addArrangedSubview(control)
        row.addArrangedSubview(detailLabel)
        return row
    }

    private func pacingRow(for button: NSButton, action: Selector, summary: String) -> NSView {
        let row = NSStackView()
        row.orientation = .vertical
        row.alignment = .leading
        row.spacing = 4

        let configuredButton = configureRadio(button, action: action)

        let summaryLabel = NSTextField(wrappingLabelWithString: summary)
        summaryLabel.font = NSFont.systemFont(ofSize: 11.5)
        summaryLabel.textColor = .secondaryLabelColor
        summaryLabel.maximumNumberOfLines = 0
        summaryLabel.preferredMaxLayoutWidth = 400

        row.addArrangedSubview(configuredButton)
        row.addArrangedSubview(summaryLabel)
        return row
    }

    private func verticalRows(_ rows: [NSView], spacing: CGFloat) -> NSView {
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        return stack
    }

    private func configureCheckbox(_ button: NSButton, action: Selector) -> NSButton {
        button.target = self
        button.action = action
        button.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        button.contentTintColor = .labelColor
        return button
    }

    private func configureRadio(_ button: NSButton, action: Selector) -> NSButton {
        button.target = self
        button.action = action
        button.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        button.contentTintColor = .labelColor
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
