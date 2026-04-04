import AppKit
import Darwin
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private enum MenuTag {
        static let title = 100
        static let account = 101
        static let plan = 102
        static let primary = 103
        static let secondary = 104
        static let refresh = 105
        static let copy = 106
        static let quit = 107
        static let recentAccountsHeader = 108
        static let paceNotice = 109
        static let updatedAt = 110
        static let accountSwitchHint = 111
        static let launchAtLogin = 112
        static let openCodexFolder = 113
        static let openLogsDatabase = 114
        static let preferences = 115
        static let showColors = 116
        static let showPaceAlert = 117
        static let showLastUpdated = 118
        static let feedback = 119
        static let source = 120
        static let accountsStart = 2000
    }

    private enum RefreshMode {
        case automatic
        case apiManual
    }

    private enum PreferenceKey {
        static let showColors = "showColors"
        static let showPaceAlert = "showPaceAlert"
        static let showLastUpdated = "showLastUpdated"
    }

    private let provider = CodexQuotaProvider()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let badgeView = StatusBadgeView(frame: NSRect(x: 0, y: 0, width: 56, height: 24))
    private let menu = NSMenu()
    private let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
    private let defaults = UserDefaults.standard
    private var refreshTimer: Timer?
    private var lastPresentation = StatusPresentation.loading
    private var isMenuOpen = false
    private var pendingAccounts: [CodexKnownAccount] = []
    private var needsAccountsRefresh = false
    private var logsMonitor: DispatchSourceFileSystemObject?
    private var logsMonitorFileDescriptor: Int32 = -1
    private var authMonitor: DispatchSourceFileSystemObject?
    private var authMonitorFileDescriptor: Int32 = -1
    private var refreshWorkItem: DispatchWorkItem?
    private var accountRefreshWorkItem: DispatchWorkItem?
    private var shouldReopenMenuAfterRefresh = false
    private var feedbackHideWorkItem: DispatchWorkItem?
    private var lastSuccessfulAPIResult: CodexQuotaFetchResult?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        defaults.register(defaults: [
            PreferenceKey.showColors: true,
            PreferenceKey.showPaceAlert: true,
            PreferenceKey.showLastUpdated: true
        ])
        configureStatusItem()
        configureMenu()
        setupFileWatchers()
        refreshAsync(mode: .automatic)
        refreshAccountsAsync()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            self?.refreshAsync(mode: .automatic)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
        teardownMonitor(&logsMonitor, fileDescriptor: &logsMonitorFileDescriptor)
        teardownMonitor(&authMonitor, fileDescriptor: &authMonitorFileDescriptor)
    }

    @objc
    private func refreshNow(_ sender: Any?) {
        shouldReopenMenuAfterRefresh = true
        refreshAsync(mode: .apiManual)
    }

    @objc
    private func copyDetails(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(lastPresentation.tooltip, forType: .string)
    }

    @objc
    private func quit(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "Quit Codex Quota Peek?"
        alert.informativeText = "The menu bar app will close until you open it again."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            NSApp.terminate(nil)
        }
    }

    @objc
    private func openCodexFolder(_ sender: Any?) {
        NSWorkspace.shared.open(homeDirectory.appendingPathComponent(".codex"))
    }

    @objc
    private func openLogsDatabase(_ sender: Any?) {
        NSWorkspace.shared.activateFileViewerSelecting([
            homeDirectory.appendingPathComponent(".codex/logs_1.sqlite")
        ])
    }

    @objc
    private func toggleShowColors(_ sender: Any?) {
        let enabled = !showsColors
        defaults.set(enabled, forKey: PreferenceKey.showColors)
        updatePreferenceMenuItems()
        apply(lastPresentation)
        showFeedback("Show Colors \(enabled ? "enabled" : "disabled")")
    }

    @objc
    private func toggleShowPaceAlert(_ sender: Any?) {
        let enabled = !showsPaceAlert
        defaults.set(enabled, forKey: PreferenceKey.showPaceAlert)
        updatePreferenceMenuItems()
        apply(lastPresentation)
        showFeedback("Show Pace Alert \(enabled ? "enabled" : "disabled")")
    }

    @objc
    private func toggleShowLastUpdated(_ sender: Any?) {
        let enabled = !showsLastUpdated
        defaults.set(enabled, forKey: PreferenceKey.showLastUpdated)
        updatePreferenceMenuItems()
        apply(lastPresentation)
        showFeedback("Show Last Updated \(enabled ? "enabled" : "disabled")")
    }

    @objc
    private func switchAccount(_ sender: NSMenuItem) {
        let targetLabel = sender.representedObject as? String ?? "selected account"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-e",
            "tell application \"Terminal\" to do script \"echo History account selected: \(targetLabel.quotedForShell()); echo Re-login is required to switch accounts.; codex login --device-auth\"",
            "-e",
            "tell application \"Terminal\" to activate"
        ]
        try? process.run()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.title = ""
        button.imagePosition = .imageOnly
        menu.delegate = self
        statusItem.menu = menu

        badgeView.line1 = lastPresentation.line1
        badgeView.line2 = lastPresentation.line2
        let image = badgeView.renderedImage()
        button.image = image
        statusItem.length = image.size.width
    }

    private func configureMenu() {
        menu.autoenablesItems = false
        menu.minimumWidth = 280

        let titleItem = NSMenuItem(title: "Codex Quota Peek", action: nil, keyEquivalent: "")
        titleItem.tag = MenuTag.title
        titleItem.isEnabled = false
        titleItem.image = NSImage(
            systemSymbolName: "gauge.open.with.lines.needle.33percent",
            accessibilityDescription: nil
        )

        let accountItem = NSMenuItem(title: "Account: --", action: nil, keyEquivalent: "")
        accountItem.tag = MenuTag.account
        accountItem.isEnabled = false

        let planItem = NSMenuItem(title: "Plan: --", action: nil, keyEquivalent: "")
        planItem.tag = MenuTag.plan
        planItem.isEnabled = false

        let recentAccountsHeader = NSMenuItem(title: "Account History", action: nil, keyEquivalent: "")
        recentAccountsHeader.tag = MenuTag.recentAccountsHeader
        recentAccountsHeader.isEnabled = false

        let primaryItem = NSMenuItem(title: "5 hours: -- | --", action: nil, keyEquivalent: "")
        primaryItem.tag = MenuTag.primary
        primaryItem.isEnabled = false

        let secondaryItem = NSMenuItem(title: "1 week: -- | --", action: nil, keyEquivalent: "")
        secondaryItem.tag = MenuTag.secondary
        secondaryItem.isEnabled = false

        let paceNoticeItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        paceNoticeItem.tag = MenuTag.paceNotice
        paceNoticeItem.isEnabled = false
        paceNoticeItem.isHidden = true

        let updatedAtItem = NSMenuItem(title: "Last updated: --", action: nil, keyEquivalent: "")
        updatedAtItem.tag = MenuTag.updatedAt
        updatedAtItem.isEnabled = false

        let sourceItem = NSMenuItem(title: "Auto refresh uses local logs", action: nil, keyEquivalent: "")
        sourceItem.tag = MenuTag.source
        sourceItem.isEnabled = false

        let accountSwitchHintItem = NSMenuItem(
            title: "History only. Switching requires re-login in Terminal.",
            action: nil,
            keyEquivalent: ""
        )
        accountSwitchHintItem.tag = MenuTag.accountSwitchHint
        accountSwitchHintItem.isEnabled = false

        let feedbackItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        feedbackItem.tag = MenuTag.feedback
        feedbackItem.isEnabled = false
        feedbackItem.isHidden = true

        let refreshItem = NSMenuItem(title: "Refresh Now (API latest)", action: #selector(refreshNow(_:)), keyEquivalent: "")
        refreshItem.tag = MenuTag.refresh
        refreshItem.target = self

        let copyItem = NSMenuItem(title: "Copy Details", action: #selector(copyDetails(_:)), keyEquivalent: "c")
        copyItem.tag = MenuTag.copy
        copyItem.target = self

        let openCodexFolderItem = NSMenuItem(title: "Open Codex Folder", action: #selector(openCodexFolder(_:)), keyEquivalent: "")
        openCodexFolderItem.tag = MenuTag.openCodexFolder
        openCodexFolderItem.target = self

        let openLogsDatabaseItem = NSMenuItem(title: "Reveal Logs Database", action: #selector(openLogsDatabase(_:)), keyEquivalent: "")
        openLogsDatabaseItem.tag = MenuTag.openLogsDatabase
        openLogsDatabaseItem.target = self

        let preferencesItem = NSMenuItem(title: "Preferences", action: nil, keyEquivalent: "")
        preferencesItem.tag = MenuTag.preferences

        let showColorsItem = NSMenuItem(title: "Show Colors", action: #selector(toggleShowColors(_:)), keyEquivalent: "")
        showColorsItem.tag = MenuTag.showColors
        showColorsItem.target = self

        let showPaceAlertItem = NSMenuItem(title: "Show Pace Alert", action: #selector(toggleShowPaceAlert(_:)), keyEquivalent: "")
        showPaceAlertItem.tag = MenuTag.showPaceAlert
        showPaceAlertItem.target = self

        let showLastUpdatedItem = NSMenuItem(title: "Show Last Updated", action: #selector(toggleShowLastUpdated(_:)), keyEquivalent: "")
        showLastUpdatedItem.tag = MenuTag.showLastUpdated
        showLastUpdatedItem.target = self

        let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchAtLoginItem.tag = MenuTag.launchAtLogin
        launchAtLoginItem.target = self

        let preferencesMenu = NSMenu(title: "Preferences")
        preferencesMenu.items = [
            showColorsItem,
            showPaceAlertItem,
            showLastUpdatedItem,
            .separator(),
            launchAtLoginItem
        ]
        preferencesItem.submenu = preferencesMenu

        let quitItem = NSMenuItem(title: "Quit...", action: #selector(quit(_:)), keyEquivalent: "q")
        quitItem.tag = MenuTag.quit
        quitItem.target = self

        menu.items = [
            titleItem,
            accountItem,
            planItem,
            .separator(),
            recentAccountsHeader,
            accountSwitchHintItem,
            feedbackItem,
            .separator(),
            primaryItem,
            secondaryItem,
            paceNoticeItem,
            updatedAtItem,
            sourceItem,
            .separator(),
            refreshItem,
            copyItem,
            openCodexFolderItem,
            openLogsDatabaseItem,
            preferencesItem,
            .separator(),
            .separator(),
            quitItem
        ]

        updateLaunchAtLoginMenuItem()
        updatePreferenceMenuItems()
    }

    private func refreshAsync(mode: RefreshMode) {
        let provider = self.provider
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let presentation: StatusPresentation
            do {
                let fetchedResult = try {
                    switch mode {
                    case .automatic:
                        return try provider.loadSnapshotForAutomaticRefresh()
                    case .apiManual:
                        return try provider.loadSnapshotUsingAPI()
                    }
                }()
                let result = resolvePreferredResult(fetchedResult, for: mode)
                let accountInfo = provider.loadAccountInfo()
                presentation = StatusPresentation(
                    snapshot: result.snapshot,
                    accountInfo: accountInfo,
                    generatedAt: Date(),
                    source: result.source
                )
            } catch {
                presentation = .unavailable(error.localizedDescription)
            }

            DispatchQueue.main.async {
                self.apply(presentation)
                if self.shouldReopenMenuAfterRefresh {
                    self.shouldReopenMenuAfterRefresh = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                        self?.statusItem.button?.performClick(nil)
                    }
                }
            }
        }
    }

    private func resolvePreferredResult(
        _ fetchedResult: CodexQuotaFetchResult,
        for mode: RefreshMode
    ) -> CodexQuotaFetchResult {
        if fetchedResult.source == .api {
            lastSuccessfulAPIResult = fetchedResult
            return fetchedResult
        }

        guard mode == .automatic, let recentAPI = lastSuccessfulAPIResult else {
            return fetchedResult
        }

        let fetchedDate = fetchedResult.sourceDate ?? .distantPast
        let apiDate = recentAPI.sourceDate ?? .distantPast
        if fetchedDate < apiDate {
            return recentAPI
        }

        return fetchedResult
    }

    @objc
    private func toggleLaunchAtLogin(_ sender: Any?) {
        let shouldEnable = item(MenuTag.launchAtLogin)?.state != .on
        setLaunchAtLogin(enabled: shouldEnable)
        updateLaunchAtLoginMenuItem()
    }

    private func setupFileWatchers() {
        let codexDirectory = homeDirectory.appendingPathComponent(".codex")
        setupLogsMonitor(at: codexDirectory.appendingPathComponent("logs_1.sqlite"))
        setupAuthMonitor(at: codexDirectory.appendingPathComponent("auth.json"))
    }

    private func setupLogsMonitor(at url: URL) {
        teardownMonitor(&logsMonitor, fileDescriptor: &logsMonitorFileDescriptor)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let monitor = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .rename, .delete],
            queue: DispatchQueue.global(qos: .utility)
        )

        monitor.setEventHandler { [weak self] in
            let event = monitor.data
            if event.contains(.delete) || event.contains(.rename) {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.teardownMonitor(&self.logsMonitor, fileDescriptor: &self.logsMonitorFileDescriptor)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.setupLogsMonitor(at: url)
                    }
                }
            }
            self?.scheduleRefresh(delay: 0.2)
        }
        monitor.setCancelHandler {
            close(descriptor)
        }
        monitor.resume()

        logsMonitor = monitor
        logsMonitorFileDescriptor = descriptor
    }

    private func setupAuthMonitor(at url: URL) {
        teardownMonitor(&authMonitor, fileDescriptor: &authMonitorFileDescriptor)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let monitor = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .rename, .delete],
            queue: DispatchQueue.global(qos: .utility)
        )

        monitor.setEventHandler { [weak self] in
            let event = monitor.data
            if event.contains(.delete) || event.contains(.rename) {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.teardownMonitor(&self.authMonitor, fileDescriptor: &self.authMonitorFileDescriptor)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.setupAuthMonitor(at: url)
                    }
                }
            }
            self?.scheduleAccountRefresh(delay: 0.2)
            self?.scheduleRefresh(delay: 0.35)
        }
        monitor.setCancelHandler {
            close(descriptor)
        }
        monitor.resume()

        authMonitor = monitor
        authMonitorFileDescriptor = descriptor
    }

    private func teardownMonitor(
        _ source: inout DispatchSourceFileSystemObject?,
        fileDescriptor: inout Int32
    ) {
        source?.cancel()
        source = nil
        fileDescriptor = -1
    }

    private func scheduleRefresh(delay: TimeInterval) {
        refreshWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.refreshAsync(mode: .automatic)
        }
        refreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func scheduleAccountRefresh(delay: TimeInterval) {
        accountRefreshWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.refreshAccountsAsync()
        }
        accountRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func refreshAccountsAsync() {
        let provider = self.provider
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let accounts = provider.loadKnownAccounts()
            DispatchQueue.main.async {
                self.pendingAccounts = accounts
                if self.isMenuOpen {
                    self.needsAccountsRefresh = true
                } else {
                    self.rebuildAccountItems()
                }
            }
        }
    }

    private func apply(_ presentation: StatusPresentation) {
        lastPresentation = presentation
        badgeView.line1 = presentation.line1
        badgeView.line2 = presentation.line2
        badgeView.showsColors = showsColors

        let image = badgeView.renderedImage()
        if let button = statusItem.button {
            button.image = nil
            button.image = image
            button.toolTip = presentation.tooltip
            button.needsDisplay = true
            button.display()
        }
        statusItem.length = image.size.width

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, let button = self.statusItem.button else { return }
            button.image = nil
            button.image = image
            button.toolTip = presentation.tooltip
            button.needsDisplay = true
            button.display()
            self.statusItem.length = image.size.width
        }

        item(MenuTag.title)?.attributedTitle = styledTitle(
            title: "Codex Quota Peek",
            subtitle: [presentation.accountRow?.value, presentation.planRow?.value]
                .compactMap { $0 }
                .joined(separator: " · ")
        )
        item(MenuTag.account)?.attributedTitle = styledLabel(
            label: presentation.accountRow?.label ?? "Account",
            value: presentation.accountRow?.value ?? "--"
        )
        item(MenuTag.plan)?.attributedTitle = styledLabel(
            label: presentation.planRow?.label ?? "Plan",
            value: presentation.planRow?.value ?? "--"
        )
        if isMenuOpen {
            needsAccountsRefresh = true
        } else {
            rebuildAccountItems()
        }

        if let primary = presentation.primaryRow {
            item(MenuTag.primary)?.attributedTitle = styledQuotaRow(
                label: primary.label,
                percent: primary.percentText,
                reset: primary.resetText
            )
        } else {
            item(MenuTag.primary)?.attributedTitle = styledQuotaRow(
                label: "5 hours",
                percent: "--",
                reset: "--"
            )
        }

        if let secondary = presentation.secondaryRow {
            item(MenuTag.secondary)?.attributedTitle = styledQuotaRow(
                label: secondary.label,
                percent: secondary.percentText,
                reset: secondary.resetText
            )
        } else {
            item(MenuTag.secondary)?.attributedTitle = styledQuotaRow(
                label: "1 week",
                percent: "--",
                reset: "--"
            )
        }

        item(MenuTag.paceNotice)?.isHidden = false
        if !showsPaceAlert {
            item(MenuTag.paceNotice)?.attributedTitle = styledMutedStatus("Pace alert hidden")
        } else if let paceMessage = presentation.paceMessage {
            item(MenuTag.paceNotice)?.attributedTitle = styledPaceNotice(
                paceMessage,
                severity: presentation.paceSeverity ?? .warning
            )
        } else {
            item(MenuTag.paceNotice)?.attributedTitle = styledMutedStatus("Pace normal")
        }

        item(MenuTag.updatedAt)?.isHidden = false
        item(MenuTag.updatedAt)?.attributedTitle = showsLastUpdated
            ? styledUpdatedAt(presentation.updatedAtText)
            : styledMutedStatus("Last updated hidden")

        item(MenuTag.source)?.isHidden = false
        item(MenuTag.source)?.attributedTitle = styledSource(presentation.sourceText)
    }

    private func item(_ tag: Int) -> NSMenuItem? {
        findItem(in: menu, tag: tag)
    }

    private func findItem(in menu: NSMenu, tag: Int) -> NSMenuItem? {
        for item in menu.items {
            if item.tag == tag {
                return item
            }
            if let submenu = item.submenu, let match = findItem(in: submenu, tag: tag) {
                return match
            }
        }
        return nil
    }

    private func updateLaunchAtLoginMenuItem() {
        item(MenuTag.launchAtLogin)?.state = isLaunchAtLoginEnabled() ? .on : .off
    }

    private func updatePreferenceMenuItems() {
        item(MenuTag.showColors)?.state = showsColors ? .on : .off
        item(MenuTag.showPaceAlert)?.state = showsPaceAlert ? .on : .off
        item(MenuTag.showLastUpdated)?.state = showsLastUpdated ? .on : .off
    }

    private func showFeedback(_ message: String) {
        feedbackHideWorkItem?.cancel()
        item(MenuTag.feedback)?.isHidden = false
        item(MenuTag.feedback)?.attributedTitle = NSAttributedString(
            string: message,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )

        let workItem = DispatchWorkItem { [weak self] in
            self?.item(MenuTag.feedback)?.isHidden = true
            self?.item(MenuTag.feedback)?.title = ""
        }
        feedbackHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: workItem)
    }

    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
        refreshAsync(mode: .automatic)
        refreshAccountsAsync()
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
        if needsAccountsRefresh {
            needsAccountsRefresh = false
            rebuildAccountItems()
        }
    }

    private func rebuildAccountItems() {
        while let existing = menu.items.first(where: { $0.tag >= MenuTag.accountsStart }) {
            menu.removeItem(existing)
        }

        let headerIndex = menu.indexOfItem(withTag: MenuTag.recentAccountsHeader)
        guard headerIndex >= 0 else {
            return
        }

        let hasAccounts = !pendingAccounts.isEmpty
        item(MenuTag.recentAccountsHeader)?.isHidden = !hasAccounts
        item(MenuTag.accountSwitchHint)?.isHidden = !hasAccounts

        guard hasAccounts else {
            return
        }

        for (offset, account) in pendingAccounts.enumerated() {
            let title = account.isCurrent ? "Current: \(account.displayName)" : "Re-login as \(account.displayName)"
            let item = NSMenuItem(title: title, action: #selector(switchAccount(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = account.email ?? account.displayName
            item.indentationLevel = 1
            item.isEnabled = !account.isCurrent
            item.tag = MenuTag.accountsStart + offset
            menu.insertItem(item, at: headerIndex + 1 + offset)
        }
    }

    private func styledTitle(title: String, subtitle: String) -> NSAttributedString {
        let result = NSMutableAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ]
        )

        if !subtitle.isEmpty {
            result.append(
                NSAttributedString(
                    string: "\n\(subtitle)",
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                        .foregroundColor: NSColor.secondaryLabelColor
                    ]
                )
            )
        }

        return result
    }

    private func styledLabel(label: String, value: String) -> NSAttributedString {
        NSMutableAttributedString(
            string: "\(label): ",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        ).appending(
            NSAttributedString(
                string: value,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                    .foregroundColor: NSColor.labelColor
                ]
            )
        )
    }

    private func styledQuotaRow(label: String, percent: String, reset: String) -> NSAttributedString {
        let paddedLabel = label.padding(toLength: 10, withPad: " ", startingAt: 0)
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        let (percentValue, percentMarker) = splitPercentComponents(percent)
        let paddedPercentValue = percentValue.leftPadding(toLength: 4)
        let paddedPercentMarker = percentMarker.padding(toLength: 2, withPad: " ", startingAt: 0)
        let line = NSMutableAttributedString(
            string: "\(paddedLabel)  ",
            attributes: [
                .font: font,
                .foregroundColor: NSColor.labelColor
            ]
        )
        line.append(
            NSAttributedString(
                string: paddedPercentValue,
                attributes: [
                    .font: font,
                    .foregroundColor: quotaColor(for: percent)
                ]
            )
        )
        line.append(
            NSAttributedString(
                string: paddedPercentMarker,
                attributes: [
                    .font: font,
                    .foregroundColor: quotaColor(for: percent)
                ]
            )
        )
        line.append(
            NSAttributedString(
                string: "  \(reset)",
                attributes: [
                    .font: font,
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
            )
        )
        return line
    }

    private func splitPercentComponents(_ percentText: String) -> (String, String) {
        let marker = percentText.filter { $0 == "!" }
        let value = percentText.replacingOccurrences(of: "!", with: "")
        return (value, marker)
    }

    private func quotaColor(for percentText: String) -> NSColor {
        guard let percent = Int(
            percentText
                .replacingOccurrences(of: "%", with: "")
                .replacingOccurrences(of: "!", with: "")
        ) else {
            return NSColor.labelColor
        }

        if percent < 30 {
            return NSColor.systemRed
        }
        if percent < 50 {
            return NSColor.systemYellow
        }
        return NSColor.systemGreen
    }

    private func styledPaceNotice(_ text: String, severity: StatusPresentation.PaceSeverity) -> NSAttributedString {
        NSAttributedString(
            string: "Pace alert: \(text)",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: severity == .critical ? NSColor.systemRed : NSColor.systemYellow
            ]
        )
    }

    private func styledUpdatedAt(_ text: String) -> NSAttributedString {
        NSAttributedString(
            string: "Last updated: \(text)",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
    }

    private func styledSource(_ text: String) -> NSAttributedString {
        NSAttributedString(
            string: "\(text) · auto refresh uses local logs",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
    }

    private func styledMutedStatus(_ text: String) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
    }

    private func isLaunchAtLoginEnabled() -> Bool {
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "CodexQuotaPeek"
        let script = """
        tell application "System Events"
            return exists login item "\(appName)"
        end tell
        """
        let output = runAppleScript(script)
        return output.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }

    private func setLaunchAtLogin(enabled: Bool) {
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "CodexQuotaPeek"
        let appPath = Bundle.main.bundleURL.path
        let script: String

        if enabled {
            script = """
            tell application "System Events"
                if not (exists login item "\(appName)") then
                    make login item at end with properties {name:"\(appName)", path:"\(appPath)", hidden:false}
                end if
            end tell
            """
        } else {
            script = """
            tell application "System Events"
                if exists login item "\(appName)" then
                    delete login item "\(appName)"
                end if
            end tell
            """
        }

        _ = runAppleScript(script)
    }

    private func runAppleScript(_ script: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }

        if process.terminationStatus != 0 {
            return ""
        }

        return String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    private var showsColors: Bool {
        defaults.bool(forKey: PreferenceKey.showColors)
    }

    private var showsPaceAlert: Bool {
        defaults.bool(forKey: PreferenceKey.showPaceAlert)
    }

    private var showsLastUpdated: Bool {
        defaults.bool(forKey: PreferenceKey.showLastUpdated)
    }
}

private extension String {
    func quotedForShell() -> String {
        replacingOccurrences(of: "\"", with: "\\\"")
    }
}

private extension NSMutableAttributedString {
    func appending(_ string: NSAttributedString) -> NSAttributedString {
        append(string)
        return self
    }
}

private extension String {
    func leftPadding(toLength length: Int, withPad pad: Character = " ") -> String {
        if count >= length { return self }
        return String(repeating: String(pad), count: length - count) + self
    }
}
