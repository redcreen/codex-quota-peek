import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let provider = CodexQuotaProvider()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let badgeView = StatusBadgeView(frame: NSRect(x: 0, y: 0, width: 56, height: 24))
    private let menu = NSMenu()
    private let headerView = MenuHeaderView()
    private let accountInfoView = MenuInfoRowView()
    private let planInfoView = MenuInfoRowView()
    private let primaryRowView = MenuValueRowView()
    private let secondaryRowView = MenuValueRowView()
    private lazy var refreshRowView = MenuActionRowView(title: "Refresh Now", target: self, action: #selector(refreshNow(_:)))
    private lazy var copyRowView = MenuActionRowView(title: "Copy Details", shortcut: "⌘C", target: self, action: #selector(copyDetails(_:)))
    private lazy var quitRowView = MenuActionRowView(title: "Quit", shortcut: "⌘Q", target: self, action: #selector(quit(_:)))
    private let accountsMenuItem = NSMenuItem(title: "Recent Accounts", action: nil, keyEquivalent: "")
    private var refreshTimer: Timer?
    private var lastPresentation = StatusPresentation.loading

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configureMenu()
        refreshAsync()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
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
        if let button = statusItem.button {
            button.title = ""
            button.imagePosition = .imageOnly
        }

        menu.delegate = self
        statusItem.menu = menu
    }

    private func configureMenu() {
        let titleItem = NSMenuItem()
        titleItem.view = headerView

        let accountItem = NSMenuItem()
        accountItem.view = accountInfoView

        let planItem = NSMenuItem()
        planItem.view = planInfoView

        let primaryItem = NSMenuItem()
        primaryItem.view = primaryRowView
        primaryItem.isEnabled = false
        primaryItem.tag = 1001

        let secondaryItem = NSMenuItem()
        secondaryItem.view = secondaryRowView
        secondaryItem.isEnabled = false
        secondaryItem.tag = 1002

        let refreshItem = NSMenuItem()
        refreshItem.view = refreshRowView

        accountsMenuItem.submenu = NSMenu(title: "Recent Accounts")

        let copyItem = NSMenuItem()
        copyItem.view = copyRowView

        let quitItem = NSMenuItem()
        quitItem.view = quitRowView

        menu.items = [
            titleItem,
            accountItem,
            planItem,
            accountsMenuItem,
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

    private func apply(_ presentation: StatusPresentation) {
        lastPresentation = presentation
        badgeView.line1 = presentation.line1
        badgeView.line2 = presentation.line2
        let image = badgeView.renderedImage()
        statusItem.button?.image = image
        statusItem.button?.toolTip = presentation.tooltip
        statusItem.length = image.size.width
        statusItem.button?.needsDisplay = true

        let accountSummary = [presentation.accountRow?.value, presentation.planRow?.value]
            .compactMap { $0 }
            .joined(separator: " · ")
        headerView.updateSubtitle(accountSummary.isEmpty ? "--" : accountSummary)
        rebuildAccountsMenu()
        accountInfoView.update(
            label: presentation.accountRow?.label ?? "Account",
            value: presentation.accountRow?.value ?? "--"
        )
        planInfoView.update(
            label: presentation.planRow?.label ?? "Plan",
            value: presentation.planRow?.value ?? "--"
        )
        primaryRowView.update(
            label: presentation.primaryRow?.label ?? "5 hours",
            percent: presentation.primaryRow?.percentText ?? "--",
            time: presentation.primaryRow?.resetText ?? "--"
        )
        secondaryRowView.update(
            label: presentation.secondaryRow?.label ?? "1 week",
            percent: presentation.secondaryRow?.percentText ?? "--",
            time: presentation.secondaryRow?.resetText ?? "--"
        )

        for view in [headerView, accountInfoView, planInfoView, primaryRowView, secondaryRowView, refreshRowView, copyRowView, quitRowView] {
            view.needsDisplay = true
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.refreshAsync()
        }
    }

    private func rebuildAccountsMenu() {
        let submenu = NSMenu(title: "Recent Accounts")
        let accounts = provider.loadKnownAccounts()

        if accounts.isEmpty {
            let empty = NSMenuItem(title: "No accounts found", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.items = [empty]
        } else {
            submenu.items = accounts.map { account in
                let title = account.isCurrent ? "\(account.displayName) (Current)" : account.displayName
                let item = NSMenuItem(title: title, action: #selector(switchAccount(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = account.email ?? account.displayName
                return item
            }
        }

        let separator = NSMenuItem.separator()
        let switchItem = NSMenuItem(title: "Switch Account...", action: #selector(switchAccount(_:)), keyEquivalent: "")
        switchItem.target = self
        switchItem.representedObject = "Codex"
        submenu.addItem(separator)
        submenu.addItem(switchItem)
        accountsMenuItem.submenu = submenu
    }
}

private extension String {
    func quotedForShell() -> String {
        replacingOccurrences(of: "\"", with: "\\\"")
    }
}
