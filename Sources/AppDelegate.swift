import AppKit
import Darwin
import Foundation
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
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
    private var displayState = DisplayStateStore()
    private var accountItemLookup: [Int: CodexKnownAccount] = [:]
    private var refreshRequestGate = RefreshRequestGate()
    private var hasTriggeredStartupAPIRefresh = false
    private var lastNotificationSnapshot: QuotaNotificationSnapshot?
    private var preferencesWindowController: PreferencesWindowController!
    private var lastPrimaryExplanationText: String?
    private var lastSecondaryExplanationText: String?
    private var pendingStatusItemRecoveryWorkItems: [DispatchWorkItem] = []
    private var needsMenuPresentationRefresh = false
    private var manualRefreshInFlight = false

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
        scheduleStatusItemRecoveryChecks()
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
        manualRefreshInFlight = true
        if isMenuOpen {
            shouldReopenMenuAfterRefresh = true
            menu.cancelTracking()
            DispatchQueue.main.async { [weak self] in
                self?.refreshAsync(mode: .apiManual)
            }
            return
        }
        refreshAsync(mode: .apiManual)
    }

    @objc
    private func selectWeeklyPaceFromMenu(_ sender: NSMenuItem) {
        switch sender.tag {
        case MenuTag.weeklyPace40:
            setWeeklyPacingMode(.workWeek40)
        case MenuTag.weeklyPace56:
            setWeeklyPacingMode(.balanced56)
        case MenuTag.weeklyPace70:
            setWeeklyPacingMode(.heavy70)
        default:
            break
        }
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
    private func showQuotaExplanation(_ sender: NSMenuItem) {
        let language = selectedAppLanguage
        let explanation: String?
        switch sender.tag {
        case MenuTag.primary:
            explanation = lastPrimaryExplanationText
        case MenuTag.secondary:
            explanation = lastSecondaryExplanationText
        default:
            explanation = nil
        }

        guard let explanation, !explanation.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = language == .english ? "Quota Details" : "额度说明"
        alert.informativeText = explanation
        alert.alertStyle = .informational
        alert.addButton(withTitle: language.okButton)
        alert.runModal()
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
        statusItem.isVisible = true
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

    private func scheduleStatusItemRecoveryChecks() {
        pendingStatusItemRecoveryWorkItems.forEach { $0.cancel() }
        pendingStatusItemRecoveryWorkItems.removeAll()

        [0.15, 0.6, 1.5].forEach { delay in
            let workItem = DispatchWorkItem { [weak self] in
                self?.ensureStatusItemAttachedDuringStartup()
            }
            pendingStatusItemRecoveryWorkItems.append(workItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }

    private func ensureStatusItemAttachedDuringStartup() {
        guard let button = statusItem.button else { return }

        if button.image == nil {
            let image = badgeView.renderedImage()
            button.image = image
            statusItem.length = image.size.width
        }

        button.needsDisplay = true
        button.display()
    }

    private func configureMenu() {
        MenuFactory.configure(menu: menu, language: selectedAppLanguage, target: self)
        updateLaunchAtLoginMenuItem()
    }

    private func refreshAsync(mode: QuotaRefreshMode, completion: (() -> Void)? = nil) {
        guard RefreshSchedulingPolicy.shouldStart(mode: mode, manualRefreshInFlight: manualRefreshInFlight) else {
            completion?()
            return
        }
        let requestID = refreshRequestGate.issue()
        let provider = self.provider
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let presentation: StatusPresentation
            let feedbackMessage: String?
            let fetchedSnapshot: CodexQuotaSnapshot?
            let fetchedAccountInfo: CodexAccountInfo?
            let fetchedTrendSummary: CodexQuotaTrendSummary?
            let fetchedSource: CodexQuotaFetchSource?
            let generatedAt: Date?
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
                let currentGeneratedAt = result.sourceDate ?? Date()
                presentation = StatusPresentation(
                    snapshot: result.snapshot,
                    accountInfo: accountInfo,
                    generatedAt: currentGeneratedAt,
                    source: result.source,
                    trendSummary: trendSummary ?? nil,
                    weeklyPacingMode: selectedWeeklyPacingMode,
                    language: selectedAppLanguage
                )
                fetchedSnapshot = result.snapshot
                fetchedAccountInfo = accountInfo
                fetchedTrendSummary = trendSummary ?? nil
                fetchedSource = result.source
                generatedAt = currentGeneratedAt
                feedbackMessage = mode == .apiManual
                    ? (selectedAppLanguage == .english ? "Refreshed from API" : "已通过 API 刷新")
                    : nil
            } catch {
                fetchedSnapshot = nil
                fetchedAccountInfo = nil
                fetchedTrendSummary = nil
                fetchedSource = nil
                generatedAt = nil
                if mode == .apiManual {
                    presentation = self.lastPresentation
                    feedbackMessage = selectedAppLanguage == .english
                        ? "API refresh failed; keeping current value"
                        : "API 刷新失败，已保留当前数据"
                } else {
                    if self.displayState.hasDisplaySnapshot {
                        presentation = self.lastPresentation
                    } else {
                        presentation = .unavailable(error.localizedDescription, language: selectedAppLanguage)
                    }
                    feedbackMessage = nil
                }
            }

            DispatchQueue.main.async {
                guard self.refreshRequestGate.shouldApply(requestID) else {
                    if mode == .apiManual {
                        self.manualRefreshInFlight = false
                    }
                    return
                }
                var presentationToApply = presentation
                if let fetchedSnapshot, let fetchedSource, let generatedAt {
                    _ = self.displayState.recordDisplayInputs(
                        snapshot: fetchedSnapshot,
                        accountInfo: fetchedAccountInfo,
                        trendSummary: fetchedTrendSummary,
                        source: fetchedSource,
                        generatedAt: generatedAt,
                        forceFreshnessUpdate: mode == .apiManual
                    )
                    if let rebuilt = self.displayState.rebuildPresentation(
                        weeklyPacingMode: self.selectedWeeklyPacingMode,
                        language: self.selectedAppLanguage
                    ) {
                        presentationToApply = rebuilt
                    }
                } else if self.displayState.hasDisplaySnapshot,
                          let rebuilt = self.displayState.rebuildPresentation(
                            weeklyPacingMode: self.selectedWeeklyPacingMode,
                            language: self.selectedAppLanguage
                          ) {
                    presentationToApply = rebuilt
                }
                self.apply(presentationToApply)
                if let feedbackMessage {
                    self.showFeedback(feedbackMessage)
                }
                if mode == .apiManual {
                    self.manualRefreshInFlight = false
                }
                completion?()
                self.maybeSendNotification(for: presentationToApply)
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
        displayState.resolvePreferredResult(fetchedResult, mode: mode)
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
        let badgeLine1 = showsPaceAlert ? presentation.line1 : stripPaceMarkers(from: presentation.line1)
        let badgeLine2 = showsPaceAlert ? presentation.line2 : stripPaceMarkers(from: presentation.line2)
        badgeView.line1 = badgeLine1
        badgeView.line2 = badgeLine2
        badgeView.showsColors = showsColors

        let image = badgeView.renderedImage()
        if let button = statusItem.button {
            button.image = nil
            button.image = image
            button.toolTip = showsPaceAlert ? presentation.tooltip : stripPaceDetails(from: presentation.tooltip)
            button.needsDisplay = true
            button.display()
        }
        statusItem.length = image.size.width

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, let button = self.statusItem.button else { return }
            button.image = nil
            button.image = image
            button.toolTip = showsPaceAlert ? presentation.tooltip : stripPaceDetails(from: presentation.tooltip)
            button.needsDisplay = true
            button.display()
            self.statusItem.length = image.size.width
        }

        if isMenuOpen {
            needsMenuPresentationRefresh = false
            let content = MenuAttributedContentBuilder.build(
                presentation: presentation,
                language: language,
                showsPaceAlert: showsPaceAlert,
                showsLastUpdated: showsLastUpdated,
                selectedWeeklyPacingMode: selectedWeeklyPacingMode,
                weeklyPaceExplanation: weeklyPaceExplanation,
                weeklyPaceInlineExplanation: weeklyPaceInlineExplanation
            )
            lastPrimaryExplanationText = content.primaryExplanationText
            lastSecondaryExplanationText = content.secondaryExplanationText
            MenuUpdater.apply(
                menu: menu,
                input: content.input
            )
            if needsAccountsRefresh {
                needsAccountsRefresh = false
                rebuildAccountItems()
            }
            return
        } else {
            rebuildAccountItems()
        }

        let content = MenuAttributedContentBuilder.build(
            presentation: presentation,
            language: language,
            showsPaceAlert: showsPaceAlert,
            showsLastUpdated: showsLastUpdated,
            selectedWeeklyPacingMode: selectedWeeklyPacingMode,
            weeklyPaceExplanation: weeklyPaceExplanation,
            weeklyPaceInlineExplanation: weeklyPaceInlineExplanation
        )
        lastPrimaryExplanationText = content.primaryExplanationText
        lastSecondaryExplanationText = content.secondaryExplanationText
        MenuUpdater.apply(
            menu: menu,
            input: content.input
        )
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
        MenuUpdater.item(tag, in: menu)
    }

    private func stripPaceMarkers(from text: String) -> String {
        text.replacingOccurrences(of: "!", with: "")
    }

    private func stripPaceDetails(from tooltip: String?) -> String? {
        guard let tooltip else { return nil }
        let filtered = tooltip
            .components(separatedBy: .newlines)
            .filter { line in
                !line.contains("Ahead of pace:") &&
                !line.contains("超出节奏：") &&
                !line.contains("pace:") &&
                !line.contains("Pace alert") &&
                !line.contains("节奏提醒") &&
                !line.contains("This only affects !") &&
                !line.contains("这只会影响 !")
            }
            .map(stripPaceMarkers(from:))
        return filtered.joined(separator: "\n")
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
        if QuotaRefreshPolicy.shouldPreferAPIMenuOpenRefresh(
            lastSource: displayState.displayedSource,
            lastGeneratedAt: displayState.displayedGeneratedAt
        ) {
            DispatchQueue.main.async { [weak self] in
                self?.refreshAsync(mode: .startupAPI)
            }
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshRelativeFreshnessLabels()
        if needsAccountsRefresh {
            needsAccountsRefresh = false
            rebuildAccountItems()
        }
    }

    private func refreshRelativeFreshnessLabels() {
        let language = selectedAppLanguage
        guard let presentation = displayState.rebuildPresentation(
            weeklyPacingMode: selectedWeeklyPacingMode,
            language: language,
            now: Date()
        ) else { return }
        lastPresentation = presentation
        let content = MenuAttributedContentBuilder.build(
            presentation: presentation,
            language: language,
            showsPaceAlert: showsPaceAlert,
            showsLastUpdated: showsLastUpdated,
            selectedWeeklyPacingMode: selectedWeeklyPacingMode,
            weeklyPaceExplanation: weeklyPaceExplanation,
            weeklyPaceInlineExplanation: weeklyPaceInlineExplanation
        )
        lastPrimaryExplanationText = content.primaryExplanationText
        lastSecondaryExplanationText = content.secondaryExplanationText
        MenuUpdater.apply(menu: menu, input: content.input)
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
        statusItem.button?.highlight(false)
        if needsMenuPresentationRefresh {
            needsMenuPresentationRefresh = false
            apply(lastPresentation)
            return
        }
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
        let entries = AccountMenuBuilder.buildEntries(
            accounts: pendingAccounts,
            language: language,
            relativeUpdatedAt: { [language] date in
                StatusPresentation.relativeUpdatedAtLabel(for: date, language: language)
            }
        )
        for (offset, account) in pendingAccounts.enumerated() {
            let entry = entries[offset]
            let item = NSMenuItem(title: entry.title, action: #selector(switchAccount(_:)), keyEquivalent: "")
            item.target = self
            item.indentationLevel = 1
            item.isEnabled = entry.isEnabled
            item.tag = MenuTag.accountsStart + offset
            accountItemLookup[item.tag] = account
            switchMenu.insertItem(item, at: insertionIndex + offset)
        }
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

    private var weeklyPaceInlineExplanation: String {
        QuotaDisplayPolicy.weeklyPaceInlineExplanation(for: selectedWeeklyPacingMode, language: selectedAppLanguage)
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
        guard mode != selectedWeeklyPacingMode else { return }
        defaults.set(mode.rawValue, forKey: PreferenceKey.weeklyPacingMode)
        syncPreferencesWindow()
        reapplyCachedPresentationForCurrentMode()
        shouldReopenMenuAfterRefresh = true
        refreshAsync(mode: .automatic)
    }

    private func reapplyCachedPresentationForCurrentMode() {
        guard let presentation = displayState.rebuildPresentation(
            weeklyPacingMode: selectedWeeklyPacingMode,
            language: selectedAppLanguage
        ) else { return }
        apply(presentation)
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
