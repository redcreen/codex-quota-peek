import Foundation

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case chinese = "zh-Hans"

    static func systemPreferred(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard let first = preferredLanguages.first?.lowercased() else {
            return .english
        }
        if first.hasPrefix("zh") {
            return .chinese
        }
        return .english
    }

    var optionTitle: String {
        switch self {
        case .english:
            return "English"
        case .chinese:
            return "中文"
        }
    }

    var menuQuotaTitle: String {
        switch self {
        case .english:
            return "Codex Quota Usage"
        case .chinese:
            return "Codex 用量"
        }
    }

    var preferencesWindowTitle: String {
        switch self {
        case .english:
            return "Codex Quota Peek Preferences"
        case .chinese:
            return "Codex Quota Peek 偏好设置"
        }
    }

    var preferencesTitle: String {
        switch self {
        case .english:
            return "Preferences"
        case .chinese:
            return "偏好设置"
        }
    }

    var preferencesSubtitle: String {
        switch self {
        case .english:
            return "Tune what appears in the menu bar, how weekly pace warnings behave, and how the app starts."
        case .chinese:
            return "调整菜单栏展示内容、每周节奏提醒的计算方式，以及应用启动行为。"
        }
    }

    var languageSectionTitle: String {
        switch self {
        case .english:
            return "Language"
        case .chinese:
            return "语言"
        }
    }

    var languageSectionDescription: String {
        switch self {
        case .english:
            return "Choose the interface language used by the menu and preferences window. Until you change it here, the app follows your macOS language."
        case .chinese:
            return "选择菜单和偏好设置窗口使用的界面语言。在你手动切换之前，应用会跟随 macOS 系统语言。"
        }
    }

    var notificationsSectionTitle: String {
        self == .english ? "Notifications" : "通知"
    }

    var notificationsSectionDescription: String {
        self == .english ? "Choose which notification categories stay active. The main switch still controls all notifications." : "选择哪些通知类型保持开启。顶部总开关仍然控制全部通知。"
    }

    var displaySectionTitle: String {
        switch self {
        case .english:
            return "Display"
        case .chinese:
            return "显示"
        }
    }

    var displaySectionDescription: String {
        switch self {
        case .english:
            return "Control which metadata stays visible in the menu bar and dropdown."
        case .chinese:
            return "控制哪些信息会持续显示在菜单栏和下拉菜单中。"
        }
    }

    var dataSourceSectionTitle: String {
        switch self {
        case .english:
            return "Data Source Strategy"
        case .chinese:
            return "数据源策略"
        }
    }

    var dataSourceSectionDescription: String {
        switch self {
        case .english:
            return "Choose how startup and automatic refresh balance freshness against local stability. Manual Refresh Now still asks the API for the latest value."
        case .chinese:
            return "选择启动和自动刷新时，最新程度与本地稳定性之间的平衡方式。手动刷新仍会优先请求 API 获取最新值。"
        }
    }

    var appSectionTitle: String {
        switch self {
        case .english:
            return "App"
        case .chinese:
            return "应用"
        }
    }

    var appSectionDescription: String {
        switch self {
        case .english:
            return "Daily startup behavior and launch preferences."
        case .chinese:
            return "日常启动行为和登录时启动设置。"
        }
    }

    var showColorsTitle: String {
        switch self {
        case .english:
            return "Show colors in menu and status bar"
        case .chinese:
            return "在菜单和状态栏中显示颜色"
        }
    }

    var showColorsDetail: String {
        switch self {
        case .english:
            return "Use green, yellow, and red to make remaining quota easier to scan."
        case .chinese:
            return "使用绿色、黄色和红色，让剩余额度更容易一眼看清。"
        }
    }

    var showPaceAlertsTitle: String {
        switch self {
        case .english:
            return "Show weekly pace alerts"
        case .chinese:
            return "显示每周节奏提醒"
        }
    }

    var showPaceAlertsDetail: String {
        switch self {
        case .english:
            return "Show inline weekly warnings when your usage is running ahead of your chosen pace."
        case .chinese:
            return "当你的每周使用速度超过所选节奏时，在界面内显示提醒。"
        }
    }

    var showLastUpdatedTitle: String {
        switch self {
        case .english:
            return "Show last updated labels"
        case .chinese:
            return "显示最近更新时间"
        }
    }

    var showLastUpdatedDetail: String {
        switch self {
        case .english:
            return "Show relative freshness labels like 12s ago or 3m ago."
        case .chinese:
            return "显示如 12s前更新、3m前更新 这样的相对时间标签。"
        }
    }

    var notificationsTitle: String {
        switch self {
        case .english:
            return "Show quota notifications"
        case .chinese:
            return "显示额度通知"
        }
    }

    var notificationsDetail: String {
        switch self {
        case .english:
            return "Send a macOS notification only when quota crosses a new threshold or a fresh pace warning appears."
        case .chinese:
            return "只在额度跨过新阈值，或新出现节奏警告时发送 macOS 通知。"
        }
    }

    var lowQuotaNotificationsTitle: String {
        self == .english ? "Low quota alerts" : "低额度提醒"
    }

    var lowQuotaNotificationsDetail: String {
        self == .english ? "Notify when 5-hour or 7-day remaining quota drops below warning thresholds." : "当 5 小时或 7 天剩余额度跌破提醒阈值时通知。"
    }

    var paceNotificationsTitle: String {
        self == .english ? "Pace alerts" : "节奏提醒"
    }

    var paceNotificationsDetail: String {
        self == .english ? "Notify when a new ! or !! pace warning appears." : "当新的 ! 或 !! 节奏警告出现时通知。"
    }

    var resetNotificationsTitle: String {
        self == .english ? "Reset reminders" : "重置提醒"
    }

    var resetNotificationsDetail: String {
        self == .english ? "Notify shortly before a 5-hour or 7-day window resets." : "在 5 小时或 7 天窗口即将重置前通知。"
    }

    var launchAtLoginTitle: String {
        switch self {
        case .english:
            return "Launch at login"
        case .chinese:
            return "登录时启动"
        }
    }

    var launchAtLoginDetail: String {
        switch self {
        case .english:
            return "Start Codex Quota Peek automatically when you sign in to macOS."
        case .chinese:
            return "在你登录 macOS 时自动启动 Codex Quota Peek。"
        }
    }

    var aboutTitle: String {
        switch self {
        case .english:
            return "About Codex Quota Peek"
        case .chinese:
            return "关于 Codex Quota Peek"
        }
    }

    var aboutBody: String {
        switch self {
        case .english:
            return "Menu bar quota monitor for Codex.\nManual refresh uses the official usage API.\nAuto refresh follows local Codex logs."
        case .chinese:
            return "一个用于查看 Codex 额度的菜单栏工具。\n手动刷新会使用官方 usage API。\n自动刷新默认跟随本地 Codex 日志。"
        }
    }

    var okButton: String {
        switch self {
        case .english:
            return "OK"
        case .chinese:
            return "确定"
        }
    }

    var accountLabel: String { self == .english ? "Account" : "账号" }
    var planLabel: String { self == .english ? "Plan" : "套餐" }
    var creditsLabel: String { self == .english ? "Credits" : "Credits" }
    var recentLowsLabel: String { self == .english ? "Recent lows" : "近期低点" }
    var recentTrendLabel: String { self == .english ? "Recent trend" : "近期走势" }
    var trendLabel: String { self == .english ? "Trend" : "趋势" }
    var leftLabel: String { self == .english ? "left" : "剩余" }
    var resetsLabel: String { self == .english ? "Resets" : "重置" }
    var sourcePrefix: String { self == .english ? "Source" : "来源" }
    var updatedPrefix: String { self == .english ? "Updated" : "更新于" }

    var refreshNowTitle: String { self == .english ? "Refresh Now (API)" : "立即刷新（API）" }
    var copyDetailsTitle: String { self == .english ? "Copy Details" : "复制详情" }
    var openCodexFolderTitle: String { self == .english ? "Open Codex Folder" : "打开 Codex 文件夹" }
    var revealLogsDatabaseTitle: String { self == .english ? "Reveal Logs Database" : "在 Finder 中显示日志数据库" }
    var statusPageTitle: String { self == .english ? "Status Page" : "状态页面" }
    var usageDashboardTitle: String { self == .english ? "Usage Dashboard" : "用量面板" }
    var preferencesMenuTitle: String { self == .english ? "Preferences..." : "偏好设置..." }
    var quitTitle: String { self == .english ? "Quit" : "退出" }
    var saveCurrentAccountSnapshotTitle: String { self == .english ? "Save Current Account Snapshot" : "保存当前账号快照" }
    var switchAccountTitle: String { self == .english ? "Switch Account…" : "切换账号…" }
    var switchAccountMenuTitle: String { self == .english ? "Switch Account" : "切换账号" }
    var accountSwitchHintTitle: String {
        switch self {
        case .english:
            return "Saved accounts switch locally. History-only accounts re-login in Terminal."
        case .chinese:
            return "已保存的账号可本地切换。仅历史记录中的账号会在 Terminal 中重新登录。"
        }
    }

    var unavailableSourceText: String { self == .english ? "Source: unavailable" : "来源：不可用" }
    var loadingTooltip: String { self == .english ? "Loading Codex limits..." : "正在加载 Codex 额度..." }
    var justUpdatedText: String { self == .english ? "just updated" : "刚刚更新" }
    var unlimitedText: String { self == .english ? "Unlimited" : "无限制" }
    var paceAboveAverageText: String { self == .english ? " Pace above avg " : " 超出平均 " }

    func windowLabel(for minutes: Int?) -> String {
        switch minutes {
        case 300:
            return self == .english ? "5 hours" : "5 小时"
        case 10080:
            return self == .english ? "7 days" : "7 天"
        case let value?:
            if value % 1440 == 0 {
                return self == .english ? "\(value / 1440) days" : "\(value / 1440) 天"
            }
            if value % 60 == 0 {
                return self == .english ? "\(value / 60) hours" : "\(value / 60) 小时"
            }
            return self == .english ? "\(value) min" : "\(value) 分钟"
        case nil:
            return self == .english ? "Window" : "窗口"
        }
    }

    func sourceText(for source: CodexQuotaFetchSource) -> String {
        switch source {
        case .api:
            return self == .english ? "Source: API" : "来源：API"
        case .realtimeLogs:
            return self == .english ? "Source: local logs" : "来源：本地日志"
        case .archivedSessions:
            return self == .english ? "Source: archived logs" : "来源：归档日志"
        }
    }

    func trendSummaryText(windowLabel: String, deltaPoints: Int?, currentPercent: Int?, lowPercent: Int?, lowDate: Date?, recentWindow: TrendWindow) -> String? {
        var details: [String] = []
        if let deltaPoints, let trendDirection = trendDirectionText(deltaPoints) {
            details.append(trendDirection)
        }
        if let lowPercent, let lowText = lowSummaryText(currentPercent: currentPercent, lowPercent: lowPercent, lowDate: lowDate, recentWindow: recentWindow) {
            details.append(lowText)
        }
        guard !details.isEmpty else { return nil }
        return self == .english
            ? "\(windowLabel) trend: \(details.joined(separator: " · "))"
            : "\(windowLabel)趋势：\(details.joined(separator: " · "))"
    }

    private func lowSummaryText(currentPercent: Int?, lowPercent: Int, lowDate: Date?, recentWindow: TrendWindow) -> String? {
        if let currentPercent, (currentPercent - lowPercent) < 5 {
            return nil
        }

            var lowText = self == .english ? "low \(lowPercent)%" : "最低 \(lowPercent)%"
            if let lowDate {
                lowText += self == .english
                    ? " at \(trendTimestamp(lowDate, recentWindow: recentWindow))"
                    : "，时间 \(trendTimestamp(lowDate, recentWindow: recentWindow))"
            }
        return lowText
    }

    enum TrendWindow {
        case day
        case week
    }

    private func trendTimestamp(_ date: Date, recentWindow: TrendWindow) -> String {
        let formatter = DateFormatter()
        switch recentWindow {
        case .day:
            formatter.dateFormat = self == .english ? "HH:mm" : "HH:mm"
        case .week:
            formatter.setLocalizedDateFormatFromTemplate(self == .english ? "MMM d" : "M月d日")
        }
        return formatter.string(from: date)
    }

    private func trendDirectionText(_ delta: Int) -> String? {
        if abs(delta) < 5 {
            return nil
        }
        if delta > 0 {
            return self == .english ? "up \(delta)pt" : "上升 \(delta) 点"
        }
        let magnitude = abs(delta)
        return self == .english ? "down \(magnitude)pt" : "下降 \(magnitude) 点"
    }

    func relativeUpdatedAtLabel(seconds: Int) -> String {
        let clampedSeconds = max(1, seconds)
        if clampedSeconds < 60 {
            return self == .english ? "\(clampedSeconds)s ago" : "\(clampedSeconds)s前更新"
        }
        let minutes = max(1, clampedSeconds / 60)
        return self == .english ? "\(minutes)m ago" : "\(minutes)m前更新"
    }

    func creditsText(balance: String?, hasCredits: Bool?, unlimited: Bool?) -> String? {
        if unlimited == true {
            return unlimitedText
        }
        if let balance, !balance.isEmpty {
            return self == .english ? "\(balance) left" : "剩余 \(balance)"
        }
        if hasCredits == false {
            return self == .english ? "0 left" : "剩余 0"
        }
        return nil
    }

    func paceMessage(labels: [String]) -> String? {
        guard !labels.isEmpty else { return nil }
        if labels.count == 1 {
            return self == .english ? "\(labels[0]) above average" : "\(labels[0]) 超出平均"
        }
        return self == .english ? labels.joined(separator: " + ") + " above average" : labels.joined(separator: " + ") + " 超出平均"
    }

    func currentAccountTitle(_ name: String) -> String {
        self == .english ? "Current: \(name)" : "当前：\(name)"
    }

    func switchToAccountTitle(_ name: String) -> String {
        self == .english ? "Switch to: \(name)" : "切换到：\(name)"
    }

    func reloginAccountTitle(_ name: String) -> String {
        self == .english ? "Re-login as \(name)" : "重新登录为：\(name)"
    }

    func savedSuffix(_ text: String) -> String {
        self == .english ? " · saved \(text)" : " · 保存于 \(text)"
    }
}
