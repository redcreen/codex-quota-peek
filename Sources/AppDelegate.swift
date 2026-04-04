import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
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
    private var refreshTimer: Timer?
    private var lastPresentation = StatusPresentation.loading

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configureMenu()
        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
    }

    @objc
    private func refreshNow(_ sender: Any?) {
        refresh()
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
        if let button = statusItem.button {
            button.title = ""
            button.imagePosition = .imageOnly
        }

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

        let copyItem = NSMenuItem()
        copyItem.view = copyRowView

        let quitItem = NSMenuItem()
        quitItem.view = quitRowView

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

    private func refresh() {
        do {
            let snapshot = try provider.loadSnapshot()
            let accountInfo = provider.loadAccountInfo()
            let presentation = StatusPresentation(snapshot: snapshot, accountInfo: accountInfo, generatedAt: Date())
            apply(presentation)
        } catch {
            apply(.unavailable(error.localizedDescription))
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
    }
}
