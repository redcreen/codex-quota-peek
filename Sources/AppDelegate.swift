import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let provider = CodexQuotaProvider()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let badgeView = StatusBadgeView(frame: NSRect(x: 0, y: 0, width: 56, height: 24))
    private let menu = NSMenu()
    private let headerView = MenuHeaderView()
    private let primaryRowView = MenuValueRowView()
    private let secondaryRowView = MenuValueRowView()
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

        let primaryItem = NSMenuItem()
        primaryItem.view = primaryRowView
        primaryItem.isEnabled = false
        primaryItem.tag = 1001

        let secondaryItem = NSMenuItem()
        secondaryItem.view = secondaryRowView
        secondaryItem.isEnabled = false
        secondaryItem.tag = 1002

        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshNow(_:)), keyEquivalent: "r")
        refreshItem.target = self

        let copyItem = NSMenuItem(title: "Copy Details", action: #selector(copyDetails(_:)), keyEquivalent: "c")
        copyItem.target = self

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit(_:)), keyEquivalent: "q")
        quitItem.target = self

        menu.items = [
            titleItem,
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
            let presentation = StatusPresentation(snapshot: snapshot, generatedAt: Date())
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
