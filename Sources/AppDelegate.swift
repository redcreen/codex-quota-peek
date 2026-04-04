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
    }

    private let provider = CodexQuotaProvider()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let badgeView = StatusBadgeView(frame: NSRect(x: 0, y: 0, width: 56, height: 24))
    private let menu = NSMenu()
    private var refreshTimer: Timer?
    private var lastPresentation = StatusPresentation.loading
    private var isMenuOpen = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configureMenu()
        refreshAsync()
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

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.title = ""
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(toggleMenu(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        menu.delegate = self
    }

    @objc
    private func toggleMenu(_ sender: Any?) {
        if isMenuOpen {
            menu.cancelTracking()
            return
        }

        statusItem.button?.highlight(true)
        statusItem.popUpMenu(menu)
        statusItem.button?.highlight(false)
    }

    private func configureMenu() {
        menu.autoenablesItems = false

        let titleItem = NSMenuItem(title: "Codex Quota Peek", action: nil, keyEquivalent: "")
        titleItem.tag = MenuTag.title
        titleItem.isEnabled = false

        let accountItem = NSMenuItem(title: "Account: --", action: nil, keyEquivalent: "")
        accountItem.tag = MenuTag.account
        accountItem.isEnabled = false

        let planItem = NSMenuItem(title: "Plan: --", action: nil, keyEquivalent: "")
        planItem.tag = MenuTag.plan
        planItem.isEnabled = false

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

        item(MenuTag.account)?.title = "Account: \(presentation.accountRow?.value ?? "--")"
        item(MenuTag.plan)?.title = "Plan: \(presentation.planRow?.value ?? "--")"

        if let primary = presentation.primaryRow {
            item(MenuTag.primary)?.title = "\(primary.label): \(primary.percentText) | \(primary.resetText)"
        } else {
            item(MenuTag.primary)?.title = "5 hours: -- | --"
        }

        if let secondary = presentation.secondaryRow {
            item(MenuTag.secondary)?.title = "\(secondary.label): \(secondary.percentText) | \(secondary.resetText)"
        } else {
            item(MenuTag.secondary)?.title = "1 week: -- | --"
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
    }
}
