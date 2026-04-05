import AppKit
import Darwin
import Foundation
import UserNotifications

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
        static let switchAccountMenu = 108
        static let paceNotice = 109
        static let updatedAt = 110
        static let accountSwitchHint = 111
        static let launchAtLogin = 112
        static let openCodexFolder = 113
        static let openLogsDatabase = 114
        static let preferences = 115
        static let feedback = 119
        static let source = 120
        static let saveAccountSnapshot = 121
        static let credits = 122
        static let openStatusPage = 123
        static let about = 124
        static let openUsageDashboard = 125
        static let trend = 126
        static let sparkline = 127
        static let accountsStart = 2000
    }

    private enum PreferenceKey {
        static let showColors = "showColors"
        static let showPaceAlert = "showPaceAlert"
        static let showLastUpdated = "showLastUpdated"
        static let weeklyPacingMode = "weeklyPacingMode"
        static let sourceStrategy = "sourceStrategy"
        static let notificationsEnabled = "notificationsEnabled"
        static let lowQuotaNotificationsEnabled = "lowQuotaNotificationsEnabled"
        static let paceNotificationsEnabled = "paceNotificationsEnabled"
        static let resetNotificationsEnabled = "resetNotificationsEnabled"
        static let appLanguage = "appLanguage"
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
    private var lastAcceptedResult: CodexQuotaFetchResult?
    private var accountItemLookup: [Int: CodexKnownAccount] = [:]
    private var refreshRequestGate = RefreshRequestGate()
    private var hasTriggeredStartupAPIRefresh = false
    private var lastNotificationSnapshot: QuotaNotificationSnapshot?
    private var preferencesWindowController: PreferencesWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        defaults.register(defaults: [
            PreferenceKey.showColors: true,
            PreferenceKey.showPaceAlert: true,
            PreferenceKey.showLastUpdated: true,
            PreferenceKey.weeklyPacingMode: WeeklyPacingMode.balanced56.rawValue,
            PreferenceKey.sourceStrategy: QuotaSourceStrategy.auto.rawValue,
            PreferenceKey.notificationsEnabled: true,
            PreferenceKey.lowQuotaNotificationsEnabled: true,
            PreferenceKey.paceNotificationsEnabled: true,
            PreferenceKey.resetNotificationsEnabled: true
        ])
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        preferencesWindowController = makePreferencesWindowController()
        configureStatusItem()
        configureMenu()
        setupFileWatchers()
        _ = provider.captureCurrentAuthSnapshot()
        refreshAsync(mode: .automatic) { [weak self] in
            self?.triggerStartupAPIRefreshIfNeeded()
        }
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
        NSApp.terminate(nil)
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
        setShowColors(!showsColors)
    }

    @objc
    private func toggleShowPaceAlert(_ sender: Any?) {
        setShowPaceAlert(!showsPaceAlert)
    }

    @objc
    private func toggleShowLastUpdated(_ sender: Any?) {
        setShowLastUpdated(!showsLastUpdated)
    }

    @objc
    private func openPreferences(_ sender: Any?) {
        syncPreferencesWindow()
        preferencesWindowController.showWindow(nil)
        preferencesWindowController.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc
    private func switchAccount(_ sender: NSMenuItem) {
        let language = selectedAppLanguage
        guard let account = accountItemLookup[sender.tag] else { return }

        if let snapshotIdentifier = account.snapshotIdentifier, account.canSwitchLocally {
            do {
                try provider.switchToStoredAccount(identifier: snapshotIdentifier)
                showFeedback(language == .english ? "Switched to \(account.displayName)" : "已切换到 \(account.displayName)")
                refreshAccountsAsync()
                refreshAsync(mode: .automatic)
                return
            } catch {
                showFeedback(language == .english ? "Switch failed: \(error.localizedDescription)" : "切换失败：\(error.localizedDescription)")
            }
        }

        let targetLabel = account.email ?? account.displayName
        _ = provider.captureCurrentAuthSnapshot()
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

    @objc
    private func saveCurrentAccountSnapshot(_ sender: Any?) {
        let language = selectedAppLanguage
        if let account = provider.captureCurrentAuthSnapshot() {
            showFeedback(language == .english ? "Saved snapshot for \(account.displayName)" : "已保存 \(account.displayName) 的快照")
            refreshAccountsAsync()
        } else {
            showFeedback(language == .english ? "Could not save current account snapshot" : "无法保存当前账号快照")
        }
    }

    @objc
    private func openStatusPage(_ sender: Any?) {
        guard let url = URL(string: "https://status.openai.com") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc
    private func openUsageDashboard(_ sender: Any?) {
        guard let url = URL(string: "https://chatgpt.com/codex/settings/usage") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc
    private func showAbout(_ sender: Any?) {
        let language = selectedAppLanguage
        let alert = NSAlert()
        alert.messageText = language.aboutTitle
        alert.informativeText = language.aboutBody
        alert.alertStyle = .informational
        alert.addButton(withTitle: language.okButton)
        alert.runModal()
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
        let language = selectedAppLanguage
        menu.autoenablesItems = false
        menu.minimumWidth = 340

        let titleItem = NSMenuItem(title: "Codex", action: nil, keyEquivalent: "")
        titleItem.tag = MenuTag.title
        titleItem.isEnabled = false
        titleItem.image = NSImage(
            systemSymbolName: "gauge.open.with.lines.needle.33percent",
            accessibilityDescription: nil
        )

        let saveAccountSnapshotItem = NSMenuItem(
            title: language.saveCurrentAccountSnapshotTitle,
            action: #selector(saveCurrentAccountSnapshot(_:)),
            keyEquivalent: ""
        )
        saveAccountSnapshotItem.tag = MenuTag.saveAccountSnapshot
        saveAccountSnapshotItem.target = self

        let accountSwitchHintItem = NSMenuItem(
            title: language.accountSwitchHintTitle,
            action: nil,
            keyEquivalent: ""
        )
        accountSwitchHintItem.tag = MenuTag.accountSwitchHint
        accountSwitchHintItem.isEnabled = false

        let switchAccountItem = NSMenuItem(title: language.switchAccountTitle, action: nil, keyEquivalent: "")
        switchAccountItem.tag = MenuTag.switchAccountMenu
        let switchAccountMenu = NSMenu(title: language.switchAccountMenuTitle)
        switchAccountMenu.items = [
            saveAccountSnapshotItem,
            .separator(),
            accountSwitchHintItem
        ]
        switchAccountItem.submenu = switchAccountMenu

        let primaryItem = NSMenuItem(title: "5 hours: -- | --", action: nil, keyEquivalent: "")
        primaryItem.tag = MenuTag.primary
        primaryItem.isEnabled = false

        let secondaryItem = NSMenuItem(title: "7 days: -- | --", action: nil, keyEquivalent: "")
        secondaryItem.tag = MenuTag.secondary
        secondaryItem.isEnabled = false

        let paceNoticeItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        paceNoticeItem.tag = MenuTag.paceNotice
        paceNoticeItem.isEnabled = false
        paceNoticeItem.isHidden = true

        let updatedAtItem = NSMenuItem(title: "--", action: nil, keyEquivalent: "")
        updatedAtItem.tag = MenuTag.updatedAt
        updatedAtItem.isEnabled = false
        updatedAtItem.isHidden = true

        let sourceItem = NSMenuItem(title: language.sourceText(for: .realtimeLogs), action: nil, keyEquivalent: "")
        sourceItem.tag = MenuTag.source
        sourceItem.isEnabled = false

        let creditsItem = NSMenuItem(title: "\(language.creditsLabel): --", action: nil, keyEquivalent: "")
        creditsItem.tag = MenuTag.credits
        creditsItem.isEnabled = false

        let trendItem = NSMenuItem(title: "\(language.recentLowsLabel): --", action: nil, keyEquivalent: "")
        trendItem.tag = MenuTag.trend
        trendItem.isEnabled = false
        trendItem.isHidden = true

        let sparklineItem = NSMenuItem(title: "\(language.recentTrendLabel): --", action: nil, keyEquivalent: "")
        sparklineItem.tag = MenuTag.sparkline
        sparklineItem.isEnabled = false
        sparklineItem.isHidden = true

        let feedbackItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        feedbackItem.tag = MenuTag.feedback
        feedbackItem.isEnabled = false
        feedbackItem.isHidden = true

        let refreshItem = NSMenuItem(title: language.refreshNowTitle, action: #selector(refreshNow(_:)), keyEquivalent: "")
        refreshItem.tag = MenuTag.refresh
        refreshItem.target = self

        let copyItem = NSMenuItem(title: language.copyDetailsTitle, action: #selector(copyDetails(_:)), keyEquivalent: "c")
        copyItem.tag = MenuTag.copy
        copyItem.target = self

        let openCodexFolderItem = NSMenuItem(title: language.openCodexFolderTitle, action: #selector(openCodexFolder(_:)), keyEquivalent: "")
        openCodexFolderItem.tag = MenuTag.openCodexFolder
        openCodexFolderItem.target = self

        let openLogsDatabaseItem = NSMenuItem(title: language.revealLogsDatabaseTitle, action: #selector(openLogsDatabase(_:)), keyEquivalent: "")
        openLogsDatabaseItem.tag = MenuTag.openLogsDatabase
        openLogsDatabaseItem.target = self

        let openStatusPageItem = NSMenuItem(title: language.statusPageTitle, action: #selector(openStatusPage(_:)), keyEquivalent: "")
        openStatusPageItem.tag = MenuTag.openStatusPage
        openStatusPageItem.target = self

        let openUsageDashboardItem = NSMenuItem(title: language.usageDashboardTitle, action: #selector(openUsageDashboard(_:)), keyEquivalent: "")
        openUsageDashboardItem.tag = MenuTag.openUsageDashboard
        openUsageDashboardItem.target = self

        let aboutItem = NSMenuItem(title: language.aboutTitle, action: #selector(showAbout(_:)), keyEquivalent: "")
        aboutItem.tag = MenuTag.about
        aboutItem.target = self

        let preferencesItem = NSMenuItem(title: language.preferencesMenuTitle, action: #selector(openPreferences(_:)), keyEquivalent: ",")
        preferencesItem.tag = MenuTag.preferences
        preferencesItem.target = self

        let quitItem = NSMenuItem(title: language.quitTitle, action: #selector(quit(_:)), keyEquivalent: "q")
        quitItem.tag = MenuTag.quit
        quitItem.target = self

        menu.items = [
            titleItem,
            .separator(),
            primaryItem,
            secondaryItem,
            creditsItem,
            trendItem,
            sparklineItem,
            paceNoticeItem,
            sourceItem,
            updatedAtItem,
            .separator(),
            refreshItem,
            switchAccountItem,
            openUsageDashboardItem,
            openStatusPageItem,
            copyItem,
            openCodexFolderItem,
            openLogsDatabaseItem,
            preferencesItem,
            feedbackItem,
            .separator(),
            aboutItem,
            .separator(),
            quitItem
        ]

        updateLaunchAtLoginMenuItem()
    }

    private func refreshAsync(mode: QuotaRefreshMode, completion: (() -> Void)? = nil) {
        let requestID = refreshRequestGate.issue()
        let provider = self.provider
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let presentation: StatusPresentation
            let feedbackMessage: String?
            do {
                let fetchedResult = try {
                    if mode == .apiManual {
                        return try provider.loadSnapshotUsingAPI()
                    }

                    switch QuotaRefreshPolicy.fetchPlan(for: mode, sourceStrategy: self.selectedSourceStrategy) {
                    case .localFirst:
                        return try provider.loadSnapshotForAutomaticRefresh()
                    case .apiPreferred:
                        return try provider.loadSnapshotUsingAPIOrFallback()
                    }
                }()
                let result = resolvePreferredResult(fetchedResult, for: mode)
                let accountInfo = provider.loadAccountInfo()
                let trendSummary = try? provider.loadTrendSummary()
                presentation = StatusPresentation(
                    snapshot: result.snapshot,
                    accountInfo: accountInfo,
                    generatedAt: Date(),
                    source: result.source,
                    trendSummary: trendSummary ?? nil,
                    weeklyPacingMode: selectedWeeklyPacingMode,
                    language: selectedAppLanguage
                )
                feedbackMessage = mode == .apiManual
                    ? (selectedAppLanguage == .english ? "Refreshed from API" : "已通过 API 刷新")
                    : nil
            } catch {
                if mode == .apiManual {
                    presentation = self.lastPresentation
                    feedbackMessage = selectedAppLanguage == .english
                        ? "API refresh failed; keeping current value"
                        : "API 刷新失败，已保留当前数据"
                } else {
                    presentation = .unavailable(error.localizedDescription, language: selectedAppLanguage)
                    feedbackMessage = nil
                }
            }

            DispatchQueue.main.async {
                guard self.refreshRequestGate.shouldApply(requestID) else {
                    return
                }
                self.apply(presentation)
                if let feedbackMessage {
                    self.showFeedback(feedbackMessage)
                }
                completion?()
                self.maybeSendNotification(for: presentation)
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
        for mode: QuotaRefreshMode
    ) -> CodexQuotaFetchResult {
        let preferred = QuotaRefreshPolicy.preferredResult(
            fetchedResult: fetchedResult,
            mode: mode,
            lastSuccessfulAPIResult: lastSuccessfulAPIResult,
            lastAcceptedResult: lastAcceptedResult
        )
        if fetchedResult.source == .api {
            lastSuccessfulAPIResult = fetchedResult
        }
        lastAcceptedResult = preferred
        return preferred
    }

    private func triggerStartupAPIRefreshIfNeeded() {
        guard !hasTriggeredStartupAPIRefresh else { return }
        hasTriggeredStartupAPIRefresh = true
        refreshAsync(mode: .startupAPI)
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
            self?.provider.captureCurrentAuthSnapshot()
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
        let language = selectedAppLanguage
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
            title: "Codex",
            subtitle: ""
        )
        item(MenuTag.account)?.attributedTitle = styledMetaRow(
            label: presentation.accountRow?.label ?? language.accountLabel,
            value: presentation.accountRow?.value ?? "--"
        )
        item(MenuTag.plan)?.attributedTitle = styledMetaRow(
            label: presentation.planRow?.label ?? language.planLabel,
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
                language: language,
                percent: primary.percentText,
                reset: primary.resetText,
                paceText: showsPaceAlert ? primary.paceText : nil,
                paceSeverity: primary.paceSeverity,
                paceOverrunPercent: primary.paceOverrunPercent
            )
            item(MenuTag.primary)?.toolTip = primary.tooltipText
        } else {
            item(MenuTag.primary)?.attributedTitle = styledQuotaRow(
                label: "5 hours",
                language: language,
                percent: "--",
                reset: "--",
                paceText: nil,
                paceSeverity: nil,
                paceOverrunPercent: nil
            )
            item(MenuTag.primary)?.toolTip = nil
        }

        if let secondary = presentation.secondaryRow {
            item(MenuTag.secondary)?.attributedTitle = styledQuotaRow(
                label: secondary.label,
                language: language,
                percent: secondary.percentText,
                reset: secondary.resetText,
                paceText: showsPaceAlert ? secondary.paceText : nil,
                paceSeverity: secondary.paceSeverity,
                paceOverrunPercent: secondary.paceOverrunPercent
            )
            item(MenuTag.secondary)?.toolTip = [secondary.tooltipText, weeklyPaceExplanation]
                .compactMap { $0 }
                .joined(separator: "\n\n")
        } else {
            item(MenuTag.secondary)?.attributedTitle = styledQuotaRow(
                label: "7 days",
                language: language,
                percent: "--",
                reset: "--",
                paceText: nil,
                paceSeverity: nil,
                paceOverrunPercent: nil
            )
            item(MenuTag.secondary)?.toolTip = weeklyPaceExplanation
        }

        item(MenuTag.paceNotice)?.isHidden = true

        item(MenuTag.updatedAt)?.isHidden = !showsLastUpdated
        if showsLastUpdated {
            item(MenuTag.updatedAt)?.attributedTitle = styledUpdatedAt(presentation.updatedAtText, source: presentation.sourceText)
        }

        item(MenuTag.source)?.isHidden = true

        item(MenuTag.credits)?.isHidden = presentation.creditsText == nil
        if let creditsText = presentation.creditsText {
            item(MenuTag.credits)?.attributedTitle = styledCredits(creditsText)
        }

        item(MenuTag.trend)?.isHidden = presentation.trendText == nil
        if let trendText = presentation.trendText {
            item(MenuTag.trend)?.attributedTitle = styledTrend(trendText)
        }

        item(MenuTag.sparkline)?.isHidden = presentation.sparklineText == nil
        if let sparklineText = presentation.sparklineText {
            item(MenuTag.sparkline)?.attributedTitle = styledSparkline(sparklineText)
        }
    }

    private func maybeSendNotification(for presentation: StatusPresentation) {
        guard notificationsEnabled else { return }
        let currentSnapshot = QuotaNotificationPolicy.snapshot(from: presentation)
        let event = QuotaNotificationPolicy.nextEvent(
            previous: lastNotificationSnapshot,
            current: currentSnapshot,
            presentation: presentation,
            preferences: notificationPreferences
        )
        lastNotificationSnapshot = currentSnapshot
        guard let event else { return }

        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = event.body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "codex-quota-peek-\(event.title)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
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
        syncPreferencesWindow()
    }

    private func syncNotificationBaseline() {
        lastNotificationSnapshot = QuotaNotificationPolicy.snapshot(from: lastPresentation)
    }

    private func clearDeliveredQuotaNotifications() {
        let center = UNUserNotificationCenter.current()
        center.getDeliveredNotifications { notifications in
            let ids = notifications
                .map(\.request.identifier)
                .filter { $0.hasPrefix("codex-quota-peek-") }
            guard !ids.isEmpty else { return }
            center.removeDeliveredNotifications(withIdentifiers: ids)
        }
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter { $0.hasPrefix("codex-quota-peek-") }
            guard !ids.isEmpty else { return }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    private func refreshNotificationPreferences() {
        syncNotificationBaseline()
        clearDeliveredQuotaNotifications()
    }

    private func ensureNotificationAuthorizationIfNeeded() {
        guard notificationsEnabled else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
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
        let language = selectedAppLanguage
        accountItemLookup.removeAll()
        guard let switchMenu = item(MenuTag.switchAccountMenu)?.submenu else {
            return
        }
        while let existing = switchMenu.items.first(where: { $0.tag >= MenuTag.accountsStart }) {
            switchMenu.removeItem(existing)
        }

        let hasAccounts = !pendingAccounts.isEmpty
        item(MenuTag.saveAccountSnapshot)?.isHidden = !hasAccounts
        item(MenuTag.accountSwitchHint)?.isHidden = !hasAccounts

        guard hasAccounts else {
            return
        }

        let insertionIndex = 2
        for (offset, account) in pendingAccounts.enumerated() {
            let title: String
            if account.isCurrent {
                title = language.currentAccountTitle(account.displayName) + "\(account.planDisplayName.map { " (\($0))" } ?? "")\(savedSuffix(for: account))"
            } else if account.canSwitchLocally {
                title = language.switchToAccountTitle(account.displayName) + "\(account.planDisplayName.map { " (\($0))" } ?? "")\(savedSuffix(for: account))"
            } else {
                title = language.reloginAccountTitle(account.displayName)
            }
            let item = NSMenuItem(title: title, action: #selector(switchAccount(_:)), keyEquivalent: "")
            item.target = self
            item.indentationLevel = 1
            item.isEnabled = !account.isCurrent
            item.tag = MenuTag.accountsStart + offset
            accountItemLookup[item.tag] = account
            switchMenu.insertItem(item, at: insertionIndex + offset)
        }
    }

    private func savedSuffix(for account: CodexKnownAccount) -> String {
        guard let date = account.snapshotUpdatedAt else { return "" }
        return selectedAppLanguage.savedSuffix(StatusPresentation.relativeUpdatedAtLabel(for: date, language: selectedAppLanguage))
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

    private func styledHeadlineValue(_ value: String, color: NSColor) -> NSAttributedString {
        NSAttributedString(
            string: value,
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: color
            ]
        )
    }

    private func styledMetaRow(label: String, value: String) -> NSAttributedString {
        let row = NSMutableAttributedString(
            string: "\(label)  ",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        row.append(
            NSAttributedString(
                string: value,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: NSColor.labelColor
                ]
            )
        )
        return row
    }

    private func styledQuotaRow(
        label: String,
        language: AppLanguage,
        percent: String,
        reset: String,
        paceText: String?,
        paceSeverity: StatusPresentation.PaceSeverity?,
        paceOverrunPercent: Double?
    ) -> NSAttributedString {
        let title = QuotaDisplayPolicy.menuWindowTitle(for: label)
        let barFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        let detailFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        let progressSlots = 28
        let (percentValue, percentMarker) = splitPercentComponents(percent)
        let progressBar = styledProgressBar(forPercentText: percent, overrunPercent: paceOverrunPercent, font: barFont, slots: progressSlots)
        let header = NSMutableAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ]
        )
        if let paceText, let paceSeverity {
            header.append(
                NSAttributedString(
                    string: paceText,
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                        .foregroundColor: paceSeverity == .warning ? NSColor.systemYellow : NSColor.systemRed
                    ]
                )
            )
        }
        header.append(NSAttributedString(string: "\n"))
        header.append(progressBar)

        let leftText = percentMarker.isEmpty ? "\(percentValue) \(language.leftLabel)" : "\(percentValue) \(percentMarker) \(language.leftLabel)"
        let rightText = "\(language.resetsLabel) \(reset)"
        let spacerCount = max(2, progressSlots - leftText.count - rightText.count)
        let detail = NSMutableAttributedString(
            string: "\n\(percentValue)",
            attributes: [
                .font: detailFont,
                .foregroundColor: quotaColor(for: percent)
            ]
        )
        if !percentMarker.isEmpty {
            detail.append(
                NSAttributedString(
                    string: " \(percentMarker) ",
                    attributes: [
                        .font: detailFont,
                        .foregroundColor: paceColor(for: percentMarker)
                    ]
                )
            )
        } else {
            detail.append(NSAttributedString(string: " ", attributes: [
                .font: detailFont,
                .foregroundColor: quotaColor(for: percent)
            ]))
        }
        detail.append(
            NSAttributedString(
                string: language.leftLabel,
                attributes: [
                    .font: detailFont,
                    .foregroundColor: quotaColor(for: percent)
                ]
            )
        )
        detail.append(
            NSAttributedString(
                string: String(repeating: " ", count: spacerCount) + rightText,
                attributes: [
                    .font: detailFont,
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
            )
        )
        header.append(detail)
        return header
    }

    private func styledProgressBar(forPercentText percentText: String, overrunPercent: Double?, font: NSFont, slots: Int) -> NSAttributedString {
        let segments = QuotaDisplayPolicy.progressSegments(forPercentText: percentText, overrunPercent: overrunPercent, slots: slots)
        let bar = NSMutableAttributedString()

        if segments.filled > 0 {
            bar.append(
                NSAttributedString(
                    string: String(repeating: "█", count: segments.filled),
                    attributes: [
                        .font: font,
                        .foregroundColor: quotaColor(for: percentText)
                    ]
                )
            )
        }

        if segments.exceeded > 0 {
            let marker = percentText.filter { $0 == "!" }
            bar.append(
                NSAttributedString(
                    string: String(repeating: "▓", count: segments.exceeded),
                    attributes: [
                        .font: font,
                        .foregroundColor: paceColor(for: marker)
                    ]
                )
            )
        }

        if segments.empty > 0 {
            bar.append(
                NSAttributedString(
                    string: String(repeating: "░", count: segments.empty),
                    attributes: [
                        .font: font,
                        .foregroundColor: NSColor.tertiaryLabelColor
                    ]
                )
            )
        }

        return bar
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

    private func paceColor(for marker: String) -> NSColor {
        marker.count >= 2 ? NSColor.systemRed : NSColor.systemYellow
    }

    private func styledUpdatedAt(_ text: String, source: String) -> NSAttributedString {
        NSAttributedString(
            string: "\(selectedAppLanguage.updatedPrefix) \(text)  \(source)",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
    }

    private func styledTrend(_ text: String) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11.5, weight: .medium),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
    }

    private func styledSparkline(_ text: String) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor.tertiaryLabelColor
            ]
        )
    }

    private func styledSource(_ text: String) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
    }

    private func styledCredits(_ text: String) -> NSAttributedString {
        NSMutableAttributedString(
            string: "\(selectedAppLanguage.creditsLabel): ",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        ).appending(
            NSAttributedString(
                string: text,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                    .foregroundColor: NSColor.labelColor
                ]
            )
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

    private var selectedWeeklyPacingMode: WeeklyPacingMode {
        WeeklyPacingMode(rawValue: defaults.string(forKey: PreferenceKey.weeklyPacingMode) ?? "") ?? .balanced56
    }

    private var selectedSourceStrategy: QuotaSourceStrategy {
        QuotaSourceStrategy(rawValue: defaults.string(forKey: PreferenceKey.sourceStrategy) ?? "") ?? .auto
    }

    private var selectedAppLanguage: AppLanguage {
        if let raw = defaults.string(forKey: PreferenceKey.appLanguage),
           let language = AppLanguage(rawValue: raw) {
            return language
        }
        return AppLanguage.systemPreferred()
    }

    private var notificationsEnabled: Bool {
        defaults.bool(forKey: PreferenceKey.notificationsEnabled)
    }

    private var lowQuotaNotificationsEnabled: Bool {
        defaults.bool(forKey: PreferenceKey.lowQuotaNotificationsEnabled)
    }

    private var paceNotificationsEnabled: Bool {
        defaults.bool(forKey: PreferenceKey.paceNotificationsEnabled)
    }

    private var resetNotificationsEnabled: Bool {
        defaults.bool(forKey: PreferenceKey.resetNotificationsEnabled)
    }

    private var notificationPreferences: QuotaNotificationPreferences {
        QuotaNotificationPreferences(
            lowQuotaEnabled: lowQuotaNotificationsEnabled,
            paceEnabled: paceNotificationsEnabled,
            resetEnabled: resetNotificationsEnabled
        )
    }

    private var weeklyPaceExplanation: String {
        QuotaDisplayPolicy.weeklyPaceExplanation(for: selectedWeeklyPacingMode, language: selectedAppLanguage)
    }

    private func makePreferencesWindowController() -> PreferencesWindowController {
        let controller = PreferencesWindowController(language: selectedAppLanguage)
        controller.onToggleShowColors = { [weak self] enabled in
            self?.setShowColors(enabled)
        }
        controller.onToggleShowPaceAlert = { [weak self] enabled in
            self?.setShowPaceAlert(enabled)
        }
        controller.onToggleShowLastUpdated = { [weak self] enabled in
            self?.setShowLastUpdated(enabled)
        }
        controller.onToggleNotifications = { [weak self] enabled in
            self?.setNotificationsEnabled(enabled)
        }
        controller.onToggleLowQuotaNotifications = { [weak self] enabled in
            self?.setLowQuotaNotificationsEnabled(enabled)
        }
        controller.onTogglePaceNotifications = { [weak self] enabled in
            self?.setPaceNotificationsEnabled(enabled)
        }
        controller.onToggleResetNotifications = { [weak self] enabled in
            self?.setResetNotificationsEnabled(enabled)
        }
        controller.onToggleLaunchAtLogin = { [weak self] enabled in
            self?.setLaunchAtLogin(enabled: enabled)
            self?.syncPreferencesWindow()
        }
        controller.onSelectWeeklyPacingMode = { [weak self] mode in
            self?.setWeeklyPacingMode(mode)
        }
        controller.onSelectSourceStrategy = { [weak self] strategy in
            self?.setSourceStrategy(strategy)
        }
        controller.onSelectLanguage = { [weak self] language in
            self?.setAppLanguage(language)
        }
        return controller
    }

    private func syncPreferencesWindow() {
        preferencesWindowController.update(with: PreferencesViewState(
            language: selectedAppLanguage,
            showColors: showsColors,
            showPaceAlert: showsPaceAlert,
            showLastUpdated: showsLastUpdated,
            launchAtLogin: isLaunchAtLoginEnabled(),
            weeklyPacingMode: selectedWeeklyPacingMode,
            sourceStrategy: selectedSourceStrategy,
            notificationsEnabled: notificationsEnabled,
            lowQuotaNotificationsEnabled: lowQuotaNotificationsEnabled,
            paceNotificationsEnabled: paceNotificationsEnabled,
            resetNotificationsEnabled: resetNotificationsEnabled
        ))
    }

    private func setShowColors(_ enabled: Bool) {
        defaults.set(enabled, forKey: PreferenceKey.showColors)
        apply(lastPresentation)
        syncPreferencesWindow()
        showFeedback(selectedAppLanguage == .english ? "Show Colors \(enabled ? "enabled" : "disabled")" : "颜色显示\(enabled ? "已开启" : "已关闭")")
    }

    private func setSourceStrategy(_ strategy: QuotaSourceStrategy) {
        defaults.set(strategy.rawValue, forKey: PreferenceKey.sourceStrategy)
        syncPreferencesWindow()
        refreshAsync(mode: .automatic)
        showFeedback(selectedAppLanguage == .english ? "Source Strategy: \(strategy.title(language: selectedAppLanguage))" : "数据源策略：\(strategy.title(language: selectedAppLanguage))")
    }

    private func setAppLanguage(_ language: AppLanguage) {
        defaults.set(language.rawValue, forKey: PreferenceKey.appLanguage)
        let wasVisible = preferencesWindowController.window?.isVisible == true
        preferencesWindowController.close()
        preferencesWindowController = makePreferencesWindowController()
        configureMenu()
        syncPreferencesWindow()
        if wasVisible {
            openPreferences(nil)
        }
        refreshAsync(mode: .automatic)
        showFeedback(language == .english ? "Language: English" : "语言：中文")
    }

    private func setNotificationsEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: PreferenceKey.notificationsEnabled)
        refreshNotificationPreferences()
        if enabled {
            ensureNotificationAuthorizationIfNeeded()
        }
        syncPreferencesWindow()
        showFeedback(selectedAppLanguage == .english ? "Notifications \(enabled ? "enabled" : "disabled")" : "通知\(enabled ? "已开启" : "已关闭")")
    }

    private func setLowQuotaNotificationsEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: PreferenceKey.lowQuotaNotificationsEnabled)
        refreshNotificationPreferences()
        syncPreferencesWindow()
        showFeedback(selectedAppLanguage == .english ? "Low quota alerts \(enabled ? "enabled" : "disabled")" : "低额度提醒\(enabled ? "已开启" : "已关闭")")
    }

    private func setPaceNotificationsEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: PreferenceKey.paceNotificationsEnabled)
        refreshNotificationPreferences()
        syncPreferencesWindow()
        showFeedback(selectedAppLanguage == .english ? "Pace alerts \(enabled ? "enabled" : "disabled")" : "节奏提醒\(enabled ? "已开启" : "已关闭")")
    }

    private func setResetNotificationsEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: PreferenceKey.resetNotificationsEnabled)
        refreshNotificationPreferences()
        syncPreferencesWindow()
        showFeedback(selectedAppLanguage == .english ? "Reset reminders \(enabled ? "enabled" : "disabled")" : "重置提醒\(enabled ? "已开启" : "已关闭")")
    }

    private func setShowPaceAlert(_ enabled: Bool) {
        defaults.set(enabled, forKey: PreferenceKey.showPaceAlert)
        apply(lastPresentation)
        syncPreferencesWindow()
        showFeedback(selectedAppLanguage == .english ? "Show Pace Alert \(enabled ? "enabled" : "disabled")" : "节奏提醒\(enabled ? "已开启" : "已关闭")")
    }

    private func setShowLastUpdated(_ enabled: Bool) {
        defaults.set(enabled, forKey: PreferenceKey.showLastUpdated)
        apply(lastPresentation)
        syncPreferencesWindow()
        showFeedback(selectedAppLanguage == .english ? "Show Last Updated \(enabled ? "enabled" : "disabled")" : "最近更新时间\(enabled ? "已开启" : "已关闭")")
    }

    private func setWeeklyPacingMode(_ mode: WeeklyPacingMode) {
        defaults.set(mode.rawValue, forKey: PreferenceKey.weeklyPacingMode)
        syncPreferencesWindow()
        refreshAsync(mode: .automatic)
        showFeedback(selectedAppLanguage == .english ? "Weekly pace: \(mode.title)" : "每周节奏：\(mode.title)")
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
