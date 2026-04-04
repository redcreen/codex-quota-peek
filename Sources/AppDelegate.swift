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
        static let accountsStart = 2000
    }

    private let provider = CodexQuotaProvider()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let badgeView = StatusBadgeView(frame: NSRect(x: 0, y: 0, width: 56, height: 24))
    private let menu = NSMenu()
    private let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configureMenu()
        setupFileWatchers()
        refreshAsync()
        refreshAccountsAsync()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.refreshAsync()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
        teardownMonitor(&logsMonitor, fileDescriptor: &logsMonitorFileDescriptor)
        teardownMonitor(&authMonitor, fileDescriptor: &authMonitorFileDescriptor)
    }

    @objc
    private func refreshNow(_ sender: Any?) {
        refreshAsync()
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
    private func switchAccount(_ sender: NSMenuItem) {
        let targetLabel = sender.representedObject as? String ?? "selected account"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-e",
            "tell application \"Terminal\" to do script \"echo Switching to \(targetLabel.quotedForShell()); codex login --device-auth\"",
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

        let recentAccountsHeader = NSMenuItem(title: "Recent Accounts", action: nil, keyEquivalent: "")
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

        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshNow(_:)), keyEquivalent: "")
        refreshItem.tag = MenuTag.refresh
        refreshItem.target = self

        let copyItem = NSMenuItem(title: "Copy Details", action: #selector(copyDetails(_:)), keyEquivalent: "c")
        copyItem.tag = MenuTag.copy
        copyItem.target = self

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit(_:)), keyEquivalent: "q")
        quitItem.tag = MenuTag.quit
        quitItem.target = self

        menu.items = [
            titleItem,
            accountItem,
            planItem,
            .separator(),
            recentAccountsHeader,
            .separator(),
            primaryItem,
            secondaryItem,
            paceNoticeItem,
            updatedAtItem,
            .separator(),
            refreshItem,
            copyItem,
            .separator(),
            quitItem
        ]
    }

    private func refreshAsync() {
        let provider = self.provider
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let presentation: StatusPresentation
            do {
                let snapshot = try provider.loadSnapshot()
                let accountInfo = provider.loadAccountInfo()
                presentation = StatusPresentation(snapshot: snapshot, accountInfo: accountInfo, generatedAt: Date())
            } catch {
                presentation = .unavailable(error.localizedDescription)
            }

            DispatchQueue.main.async {
                self.apply(presentation)
            }
        }
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
            self?.refreshAsync()
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

        let image = badgeView.renderedImage()
        statusItem.button?.image = image
        statusItem.button?.toolTip = presentation.tooltip
        statusItem.length = image.size.width
        statusItem.button?.needsDisplay = true

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

        if let paceMessage = presentation.paceMessage {
            item(MenuTag.paceNotice)?.isHidden = false
            item(MenuTag.paceNotice)?.attributedTitle = styledPaceNotice(
                paceMessage,
                severity: presentation.paceSeverity ?? .warning
            )
        } else {
            item(MenuTag.paceNotice)?.isHidden = true
            item(MenuTag.paceNotice)?.title = ""
        }

        item(MenuTag.updatedAt)?.attributedTitle = styledUpdatedAt(presentation.updatedAtText)
    }

    private func item(_ tag: Int) -> NSMenuItem? {
        menu.item(withTag: tag)
    }

    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
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

        if pendingAccounts.isEmpty {
            let emptyItem = NSMenuItem(title: "No accounts found", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            emptyItem.tag = MenuTag.accountsStart
            menu.insertItem(emptyItem, at: headerIndex + 1)
            return
        }

        for (offset, account) in pendingAccounts.enumerated() {
            let title = account.isCurrent ? "\(account.displayName) (Current)" : account.displayName
            let item = NSMenuItem(title: title, action: #selector(switchAccount(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = account.email ?? account.displayName
            item.indentationLevel = 1
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
        let paddedPercent = percent.leftPadding(toLength: 4)
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        let line = NSMutableAttributedString(
            string: "\(paddedLabel)  ",
            attributes: [
                .font: font,
                .foregroundColor: NSColor.labelColor
            ]
        )
        line.append(
            NSAttributedString(
                string: paddedPercent,
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
