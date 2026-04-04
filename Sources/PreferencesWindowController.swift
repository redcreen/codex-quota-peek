import AppKit

struct PreferencesViewState {
    var language: AppLanguage
    var showColors: Bool
    var showPaceAlert: Bool
    var showLastUpdated: Bool
    var launchAtLogin: Bool
    var weeklyPacingMode: WeeklyPacingMode
    var sourceStrategy: QuotaSourceStrategy
    var notificationsEnabled: Bool
    var lowQuotaNotificationsEnabled: Bool
    var paceNotificationsEnabled: Bool
    var resetNotificationsEnabled: Bool
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
    private let language: AppLanguage
    var onToggleShowColors: ((Bool) -> Void)?
    var onToggleShowPaceAlert: ((Bool) -> Void)?
    var onToggleShowLastUpdated: ((Bool) -> Void)?
    var onToggleNotifications: ((Bool) -> Void)?
    var onToggleLowQuotaNotifications: ((Bool) -> Void)?
    var onTogglePaceNotifications: ((Bool) -> Void)?
    var onToggleResetNotifications: ((Bool) -> Void)?
    var onToggleLaunchAtLogin: ((Bool) -> Void)?
    var onSelectWeeklyPacingMode: ((WeeklyPacingMode) -> Void)?
    var onSelectSourceStrategy: ((QuotaSourceStrategy) -> Void)?
    var onSelectLanguage: ((AppLanguage) -> Void)?

    private let showColorsButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let showPaceAlertButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let showLastUpdatedButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let notificationsButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let lowQuotaNotificationsButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let paceNotificationsButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let resetNotificationsButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let launchAtLoginButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let autoSourceButton = NSButton(radioButtonWithTitle: "", target: nil, action: nil)
    private let apiSourceButton = NSButton(radioButtonWithTitle: "", target: nil, action: nil)
    private let localLogsSourceButton = NSButton(radioButtonWithTitle: "", target: nil, action: nil)
    private let englishLanguageButton = NSButton(radioButtonWithTitle: AppLanguage.english.optionTitle, target: nil, action: nil)
    private let chineseLanguageButton = NSButton(radioButtonWithTitle: AppLanguage.chinese.optionTitle, target: nil, action: nil)

    private let standardPaceButton = NSButton(radioButtonWithTitle: "", target: nil, action: nil)
    private let balancedPaceButton = NSButton(radioButtonWithTitle: "", target: nil, action: nil)
    private let heavyPaceButton = NSButton(radioButtonWithTitle: "", target: nil, action: nil)

    private let weeklyExplanationLabel = NSTextField(wrappingLabelWithString: "")

    init(language: AppLanguage) {
        self.language = language
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 560),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = language.preferencesWindowTitle
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        setup()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func update(with state: PreferencesViewState) {
        standardPaceButton.title = WeeklyPacingMode.workWeek40.menuTitle(language: language)
        balancedPaceButton.title = WeeklyPacingMode.balanced56.menuTitle(language: language)
        heavyPaceButton.title = WeeklyPacingMode.heavy70.menuTitle(language: language)
        autoSourceButton.title = QuotaSourceStrategy.auto.title(language: language)
        apiSourceButton.title = QuotaSourceStrategy.preferAPI.title(language: language)
        localLogsSourceButton.title = QuotaSourceStrategy.preferLocalLogs.title(language: language)
        englishLanguageButton.state = state.language == .english ? .on : .off
        chineseLanguageButton.state = state.language == .chinese ? .on : .off
        showColorsButton.state = state.showColors ? .on : .off
        showPaceAlertButton.state = state.showPaceAlert ? .on : .off
        showLastUpdatedButton.state = state.showLastUpdated ? .on : .off
        notificationsButton.state = state.notificationsEnabled ? .on : .off
        lowQuotaNotificationsButton.state = state.lowQuotaNotificationsEnabled ? .on : .off
        paceNotificationsButton.state = state.paceNotificationsEnabled ? .on : .off
        resetNotificationsButton.state = state.resetNotificationsEnabled ? .on : .off
        launchAtLoginButton.state = state.launchAtLogin ? .on : .off
        lowQuotaNotificationsButton.isEnabled = state.notificationsEnabled
        paceNotificationsButton.isEnabled = state.notificationsEnabled
        resetNotificationsButton.isEnabled = state.notificationsEnabled

        standardPaceButton.state = state.weeklyPacingMode == .workWeek40 ? .on : .off
        balancedPaceButton.state = state.weeklyPacingMode == .balanced56 ? .on : .off
        heavyPaceButton.state = state.weeklyPacingMode == .heavy70 ? .on : .off
        autoSourceButton.state = state.sourceStrategy == .auto ? .on : .off
        apiSourceButton.state = state.sourceStrategy == .preferAPI ? .on : .off
        localLogsSourceButton.state = state.sourceStrategy == .preferLocalLogs ? .on : .off
        weeklyExplanationLabel.stringValue = QuotaDisplayPolicy.weeklyPaceExplanation(for: state.weeklyPacingMode, language: language)
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
        contentStack.addArrangedSubview(makeLanguageCard())
        contentStack.addArrangedSubview(makeDisplayCard())
        contentStack.addArrangedSubview(makeSourceCard())
        contentStack.addArrangedSubview(makeWeeklyPacingCard())
        contentStack.addArrangedSubview(makeAppCard())
    }

    private func makeHeader() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6

        let titleLabel = NSTextField(labelWithString: language.preferencesTitle)
        titleLabel.font = NSFont.systemFont(ofSize: 26, weight: .semibold)
        titleLabel.textColor = .labelColor

        let subtitleLabel = NSTextField(wrappingLabelWithString: language.preferencesSubtitle)
        subtitleLabel.font = NSFont.systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.maximumNumberOfLines = 0
        subtitleLabel.preferredMaxLayoutWidth = 500

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        return stack
    }

    private func makeLanguageCard() -> NSView {
        let englishSummary = language == .english ? "Use English throughout the app UI." : "整个应用界面使用英文。"
        let chineseSummary = language == .english ? "Use Simplified Chinese throughout the app UI." : "整个应用界面使用简体中文。"
        let rows = [
            pacingRow(for: englishLanguageButton, action: #selector(selectLanguage(_:)), summary: englishSummary),
            pacingRow(for: chineseLanguageButton, action: #selector(selectLanguage(_:)), summary: chineseSummary)
        ]

        return sectionCard(
            title: language.languageSectionTitle,
            description: language.languageSectionDescription,
            body: verticalRows(rows, spacing: 14)
        )
    }

    private func makeDisplayCard() -> NSView {
        let rows = [
            optionRow(
                control: configureCheckbox(showColorsButton, action: #selector(toggleShowColors(_:)), title: language.showColorsTitle),
                detail: language.showColorsDetail
            ),
            optionRow(
                control: configureCheckbox(showPaceAlertButton, action: #selector(toggleShowPaceAlert(_:)), title: language.showPaceAlertsTitle),
                detail: language.showPaceAlertsDetail
            ),
            optionRow(
                control: configureCheckbox(showLastUpdatedButton, action: #selector(toggleShowLastUpdated(_:)), title: language.showLastUpdatedTitle),
                detail: language.showLastUpdatedDetail
            ),
            optionRow(
                control: configureCheckbox(notificationsButton, action: #selector(toggleNotifications(_:)), title: language.notificationsTitle),
                detail: language.notificationsDetail
            ),
            optionRow(
                control: configureCheckbox(lowQuotaNotificationsButton, action: #selector(toggleLowQuotaNotifications(_:)), title: language.lowQuotaNotificationsTitle),
                detail: language.lowQuotaNotificationsDetail
            ),
            optionRow(
                control: configureCheckbox(paceNotificationsButton, action: #selector(togglePaceNotifications(_:)), title: language.paceNotificationsTitle),
                detail: language.paceNotificationsDetail
            ),
            optionRow(
                control: configureCheckbox(resetNotificationsButton, action: #selector(toggleResetNotifications(_:)), title: language.resetNotificationsTitle),
                detail: language.resetNotificationsDetail
            )
        ]

        return sectionCard(
            title: language.displaySectionTitle,
            description: language.displaySectionDescription,
            body: verticalRows(rows, spacing: 14)
        )
    }

    private func makeWeeklyPacingCard() -> NSView {
        weeklyExplanationLabel.font = NSFont.systemFont(ofSize: 12)
        weeklyExplanationLabel.textColor = .secondaryLabelColor
        weeklyExplanationLabel.maximumNumberOfLines = 0
        weeklyExplanationLabel.preferredMaxLayoutWidth = 430

        let rows = [
            pacingRow(for: standardPaceButton, action: #selector(selectWeeklyPacing(_:)), summary: WeeklyPacingMode.workWeek40.summary(language: language)),
            pacingRow(for: balancedPaceButton, action: #selector(selectWeeklyPacing(_:)), summary: WeeklyPacingMode.balanced56.summary(language: language)),
            pacingRow(for: heavyPaceButton, action: #selector(selectWeeklyPacing(_:)), summary: WeeklyPacingMode.heavy70.summary(language: language)),
            weeklyExplanationLabel
        ]

        return sectionCard(
            title: QuotaDisplayPolicy.weeklyPacingSectionTitle(language: language),
            description: QuotaDisplayPolicy.weeklyPacingHintDetail(language: language),
            body: verticalRows(rows, spacing: 14)
        )
    }

    private func makeSourceCard() -> NSView {
        let rows = [
            pacingRow(for: autoSourceButton, action: #selector(selectSourceStrategy(_:)), summary: QuotaSourceStrategy.auto.summary(language: language)),
            pacingRow(for: apiSourceButton, action: #selector(selectSourceStrategy(_:)), summary: QuotaSourceStrategy.preferAPI.summary(language: language)),
            pacingRow(for: localLogsSourceButton, action: #selector(selectSourceStrategy(_:)), summary: QuotaSourceStrategy.preferLocalLogs.summary(language: language))
        ]

        return sectionCard(
            title: language.dataSourceSectionTitle,
            description: language.dataSourceSectionDescription,
            body: verticalRows(rows, spacing: 14)
        )
    }

    private func makeAppCard() -> NSView {
        let rows = [
            optionRow(
                control: configureCheckbox(launchAtLoginButton, action: #selector(toggleLaunchAtLogin(_:)), title: language.launchAtLoginTitle),
                detail: language.launchAtLoginDetail
            )
        ]

        return sectionCard(
            title: language.appSectionTitle,
            description: language.appSectionDescription,
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

    private func configureCheckbox(_ button: NSButton, action: Selector, title: String) -> NSButton {
        button.target = self
        button.action = action
        button.title = title
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
    private func selectLanguage(_ sender: NSButton) {
        onSelectLanguage?(sender === chineseLanguageButton ? .chinese : .english)
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
    private func toggleNotifications(_ sender: NSButton) {
        onToggleNotifications?(sender.state == .on)
    }

    @objc
    private func toggleLowQuotaNotifications(_ sender: NSButton) {
        onToggleLowQuotaNotifications?(sender.state == .on)
    }

    @objc
    private func togglePaceNotifications(_ sender: NSButton) {
        onTogglePaceNotifications?(sender.state == .on)
    }

    @objc
    private func toggleResetNotifications(_ sender: NSButton) {
        onToggleResetNotifications?(sender.state == .on)
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

    @objc
    private func selectSourceStrategy(_ sender: NSButton) {
        if sender === apiSourceButton {
            onSelectSourceStrategy?(.preferAPI)
        } else if sender === localLogsSourceButton {
            onSelectSourceStrategy?(.preferLocalLogs)
        } else {
            onSelectSourceStrategy?(.auto)
        }
    }
}
