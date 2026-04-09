import AppKit
import Foundation

enum MenuFactory {
    static func buildMenu(language: AppLanguage, target: AnyObject) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.minimumWidth = 340
        menu.items = [
            titleItem(),
            .separator(),
            disabledItem(title: "--", tag: MenuTag.account),
            disabledItem(title: "--", tag: MenuTag.plan),
            .separator(),
            quotaItem(tag: MenuTag.primary, target: target),
            quotaItem(tag: MenuTag.secondary, target: target),
            weeklySelectorItem(language: language, target: target),
            hiddenDisabledItem(tag: MenuTag.paceNotice),
            disabledItem(title: "\(language.creditsLabel): --", tag: MenuTag.credits),
            hiddenDisabledItem(title: "\(language.recentLowsLabel): --", tag: MenuTag.trend),
            hiddenDisabledItem(title: "\(language.recentTrendLabel): --", tag: MenuTag.sparkline),
            disabledItem(title: language.sourceText(for: .realtimeLogs), tag: MenuTag.source),
            hiddenDisabledItem(title: "--", tag: MenuTag.updatedAt),
            .separator(),
            actionItem(title: language.refreshNowTitle, tag: MenuTag.refresh, action: Selector(("refreshNow:")), keyEquivalent: "", target: target),
            switchAccountItem(language: language, target: target),
            actionItem(title: language.usageDashboardTitle, tag: MenuTag.openUsageDashboard, action: Selector(("openUsageDashboard:")), keyEquivalent: "", target: target),
            actionItem(title: language.statusPageTitle, tag: MenuTag.openStatusPage, action: Selector(("openStatusPage:")), keyEquivalent: "", target: target),
            actionItem(title: language.copyDetailsTitle, tag: MenuTag.copy, action: Selector(("copyDetails:")), keyEquivalent: "c", target: target),
            actionItem(title: language.openCodexFolderTitle, tag: MenuTag.openCodexFolder, action: Selector(("openCodexFolder:")), keyEquivalent: "", target: target),
            actionItem(title: language.revealLogsDatabaseTitle, tag: MenuTag.openLogsDatabase, action: Selector(("openLogsDatabase:")), keyEquivalent: "", target: target),
            actionItem(title: language.preferencesMenuTitle, tag: MenuTag.preferences, action: Selector(("openPreferences:")), keyEquivalent: ",", target: target),
            hiddenDisabledItem(tag: MenuTag.feedback),
            .separator(),
            actionItem(title: language.aboutTitle, tag: MenuTag.about, action: Selector(("showAbout:")), keyEquivalent: "", target: target),
            .separator(),
            actionItem(title: language.quitTitle, tag: MenuTag.quit, action: Selector(("quit:")), keyEquivalent: "q", target: target)
        ]
        return menu
    }

    private static func titleItem() -> NSMenuItem {
        let item = disabledItem(title: "Codex", tag: MenuTag.title)
        item.image = NSImage(systemSymbolName: "gauge.open.with.lines.needle.33percent", accessibilityDescription: nil)
        return item
    }

    private static func disabledItem(title: String, tag: Int) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.tag = tag
        item.isEnabled = false
        return item
    }

    private static func hiddenDisabledItem(title: String = "", tag: Int) -> NSMenuItem {
        let item = disabledItem(title: title, tag: tag)
        item.isHidden = true
        return item
    }

    private static func quotaItem(tag: Int, target: AnyObject) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: Selector(("showQuotaExplanation:")), keyEquivalent: "")
        item.tag = tag
        item.target = target
        return item
    }

    private static func weeklySelectorItem(language: AppLanguage, target: AnyObject) -> NSMenuItem {
        let title = language == .english ? "Weekly work hours" : "每周工作时长"
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.tag = MenuTag.weeklyPaceSelector
        let submenu = NSMenu(title: title)
        submenu.items = [
            weeklyOption(title: "40h", tag: MenuTag.weeklyPace40, target: target),
            weeklyOption(title: "56h", tag: MenuTag.weeklyPace56, target: target),
            weeklyOption(title: "70h", tag: MenuTag.weeklyPace70, target: target)
        ]
        item.submenu = submenu
        return item
    }

    private static func weeklyOption(title: String, tag: Int, target: AnyObject) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: Selector(("selectWeeklyPaceFromMenu:")), keyEquivalent: "")
        item.tag = tag
        item.target = target
        return item
    }

    private static func switchAccountItem(language: AppLanguage, target: AnyObject) -> NSMenuItem {
        let saveItem = NSMenuItem(title: language.saveCurrentAccountSnapshotTitle, action: Selector(("saveCurrentAccountSnapshot:")), keyEquivalent: "")
        saveItem.tag = MenuTag.saveAccountSnapshot
        saveItem.target = target

        let hintItem = disabledItem(title: language.accountSwitchHintTitle, tag: MenuTag.accountSwitchHint)

        let item = NSMenuItem(title: language.switchAccountTitle, action: nil, keyEquivalent: "")
        item.tag = MenuTag.switchAccountMenu
        let submenu = NSMenu(title: language.switchAccountMenuTitle)
        submenu.items = [saveItem, .separator(), hintItem]
        item.submenu = submenu
        return item
    }

    private static func actionItem(title: String, tag: Int, action: Selector, keyEquivalent: String, target: AnyObject) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.tag = tag
        item.target = target
        return item
    }
}
