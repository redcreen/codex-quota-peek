import AppKit
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
        static let accountsStart = 2000
    }

    private let provider = CodexQuotaProvider()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let badgeView = StatusBadgeView(frame: NSRect(x: 0, y: 0, width: 56, height: 24))
    private let menu = NSMenu()
    private var refreshTimer: Timer?
    private var lastPresentation = StatusPresentation.loading
    private var isMenuOpen = false
    private var pendingAccounts: [CodexKnownAccount] = []
    private var needsAccountsRefresh = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configureMenu()
        refreshAsync()
        refreshAccountsAsync()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.refreshAsync()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
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
        button.target = self
        button.action = #selector(toggleMenu(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        menu.delegate = self

        badgeView.line1 = lastPresentation.line1
        badgeView.line2 = lastPresentation.line2
        let image = badgeView.renderedImage()
        button.image = image
        statusItem.length = image.size.width
    }

    @objc
    private func toggleMenu(_ sender: Any?) {
        if isMenuOpen {
            menu.cancelTracking()
            return
        }

        refreshAccountsAsync()
        statusItem.button?.highlight(true)
        statusItem.popUpMenu(menu)
        statusItem.button?.highlight(false)
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
    }

    private func item(_ tag: Int) -> NSMenuItem? {
        menu.item(withTag: tag)
    }

    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
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
        let line = "\(paddedLabel)  \(paddedPercent)  \(reset)"
        return NSAttributedString(
            string: line,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.labelColor
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
