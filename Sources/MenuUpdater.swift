import AppKit
import Foundation

struct MenuUpdaterInput {
    let language: AppLanguage
    let presentation: StatusPresentation
    let selectedWeeklyPacingMode: WeeklyPacingMode
    let showsLastUpdated: Bool
    let title: NSAttributedString
    let account: NSAttributedString
    let primary: NSAttributedString
    let secondary: NSAttributedString
    let paceNotice: NSAttributedString
    let updatedAt: NSAttributedString?
    let credits: NSAttributedString?
    let trend: NSAttributedString?
}

enum MenuUpdater {
    static func apply(menu: NSMenu, input: MenuUpdaterInput) {
        item(MenuTag.title, in: menu)?.attributedTitle = input.title
        item(MenuTag.account, in: menu)?.attributedTitle = input.account
        item(MenuTag.plan, in: menu)?.isHidden = true

        item(MenuTag.primary, in: menu)?.attributedTitle = input.primary
        item(MenuTag.primary, in: menu)?.isHidden = false

        item(MenuTag.secondary, in: menu)?.attributedTitle = input.secondary
        item(MenuTag.secondary, in: menu)?.isHidden = false

        item(MenuTag.weeklyPaceSelector, in: menu)?.title = input.language == .english ? "Weekly work hours" : "每周工作时长"
        item(MenuTag.weeklyPaceSelector, in: menu)?.toolTip = nil
        item(MenuTag.weeklyPace40, in: menu)?.state = input.selectedWeeklyPacingMode == .workWeek40 ? .on : .off
        item(MenuTag.weeklyPace56, in: menu)?.state = input.selectedWeeklyPacingMode == .balanced56 ? .on : .off
        item(MenuTag.weeklyPace70, in: menu)?.state = input.selectedWeeklyPacingMode == .heavy70 ? .on : .off

        item(MenuTag.paceNotice, in: menu)?.isHidden = false
        item(MenuTag.paceNotice, in: menu)?.attributedTitle = input.paceNotice

        item(MenuTag.updatedAt, in: menu)?.isHidden = !input.showsLastUpdated
        if let updatedAt = input.updatedAt {
            item(MenuTag.updatedAt, in: menu)?.attributedTitle = updatedAt
        }

        item(MenuTag.source, in: menu)?.isHidden = true

        item(MenuTag.credits, in: menu)?.isHidden = input.credits == nil
        if let credits = input.credits {
            item(MenuTag.credits, in: menu)?.attributedTitle = credits
        }

        item(MenuTag.trend, in: menu)?.isHidden = input.trend == nil
        if let trend = input.trend {
            item(MenuTag.trend, in: menu)?.attributedTitle = trend
        }

        item(MenuTag.sparkline, in: menu)?.isHidden = true
    }

    static func item(_ tag: Int, in menu: NSMenu) -> NSMenuItem? {
        for item in menu.items {
            if item.tag == tag {
                return item
            }
            if let submenu = item.submenu, let match = self.item(tag, in: submenu) {
                return match
            }
        }
        return nil
    }
}
