import Foundation

enum QuotaDisplayColorLevel {
    case normal
    case warning
    case critical
}

enum WeeklyPacingMode: String, CaseIterable {
    case workWeek40
    case balanced56
    case heavy70

    var title: String {
        switch self {
        case .workWeek40:
            return "40h/week"
        case .balanced56:
            return "56h/week"
        case .heavy70:
            return "70h/week"
        }
    }

    var weeklyHours: Int {
        switch self {
        case .workWeek40:
            return 40
        case .balanced56:
            return 56
        case .heavy70:
            return 70
        }
    }

    var paceSeverityBoost: Double {
        switch self {
        case .workWeek40:
            return 0
        case .balanced56:
            return 5
        case .heavy70:
            return 10
        }
    }

    var displayThresholdAdjustment: Double {
        switch self {
        case .workWeek40:
            return 10
        case .balanced56:
            return 0
        case .heavy70:
            return -10
        }
    }

    var label: String {
        label(language: .english)
    }

    func label(language: AppLanguage) -> String {
        switch self {
        case .workWeek40:
            return language == .english ? "Standard" : "标准"
        case .balanced56:
            return language == .english ? "Balanced" : "平衡"
        case .heavy70:
            return language == .english ? "Heavy" : "重度"
        }
    }

    var menuTitle: String {
        menuTitle(language: .english)
    }

    func menuTitle(language: AppLanguage) -> String {
        "\(label(language: language)) · \(title)"
    }

    var summary: String {
        summary(language: .english)
    }

    func summary(language: AppLanguage) -> String {
        switch self {
        case .workWeek40:
            return language == .english ? "Loosest weekly severity." : "每周提醒最宽松。"
        case .balanced56:
            return language == .english ? "Balanced weekly severity." : "平衡的每周提醒。"
        case .heavy70:
            return language == .english ? "Strictest weekly severity." : "每周提醒最严格。"
        }
    }

    func tooltipText(language: AppLanguage = .english) -> String {
        language == .english ? "Uses this week's elapsed time for the warning baseline. The \(weeklyHours)-hour preset adds a severity boost of \(Int(paceSeverityBoost)) points after the warning appears." : "先按本周已经过去的物理时间计算是否触发提醒。\(weeklyHours) 小时档位会在触发后额外增加 \(Int(paceSeverityBoost)) 点严重度。"
    }

    func detailedTooltipText(language: AppLanguage = .english) -> String {
        language == .english ? "\(tooltipText(language: language)) \(summary(language: language)) This only affects ! pace alerts, not % left." : "\(tooltipText(language: language)) \(summary(language: language)) 这只会影响 ! 节奏提醒，不会改变剩余百分比。"
    }
}

enum QuotaDisplayPolicy {
    static func weeklyPacingSectionTitle(language: AppLanguage = .english) -> String {
        language == .english ? "Weekly ! Alert" : "每周 ! 提醒"
    }

    static func weeklyPacingHintTitle(language: AppLanguage = .english) -> String {
        language == .english ? "! appears when weekly usage is ahead of your selected pace." : "! 会在每周使用速度超过所选节奏时出现。"
    }

    static func weeklyPacingHintDetail(language: AppLanguage = .english) -> String {
        language == .english ? "40h warns sooner. 70h warns later. % left never changes." : "40 小时会更早提醒，70 小时会更晚提醒。剩余百分比不会变化。"
    }

    static func menuWindowTitle(for label: String) -> String {
        label
    }

    static func weeklyPaceExplanation(for mode: WeeklyPacingMode, language: AppLanguage = .english) -> String {
        language == .english ? "! means weekly usage is ahead of this week's elapsed time. The \(mode.weeklyHours)-hour preset only changes severity: 70h is stricter, 40h is looser. This never changes % left." : "! 表示每周使用速度超过了本周已经过去的时间进度。\(mode.weeklyHours) 小时档位只会影响严重程度：70 小时更严格，40 小时更宽松。它不会改变剩余百分比。"
    }

    static func colorLevel(forPercentText percentText: String) -> QuotaDisplayColorLevel? {
        guard let percent = Int(
            percentText
                .replacingOccurrences(of: "%", with: "")
                .replacingOccurrences(of: "!", with: "")
        ) else {
            return nil
        }

        if percent < 30 {
            return .critical
        }
        if percent < 50 {
            return .warning
        }
        return .normal
    }

    static func splitPercentComponents(_ percentText: String) -> (String, String) {
        let marker = percentText.filter { $0 == "!" }
        let value = percentText.replacingOccurrences(of: "!", with: "")
        return (value, marker)
    }

    static func progressBar(forPercentText percentText: String, slots: Int = 18) -> String {
        guard let percent = Int(
            percentText
                .replacingOccurrences(of: "%", with: "")
                .replacingOccurrences(of: "!", with: "")
        ) else {
            return String(repeating: "—", count: slots)
        }

        let filled = max(0, min(slots, Int((Double(percent) / 100.0 * Double(slots)).rounded())))
        return String(repeating: "█", count: filled) + String(repeating: "░", count: max(0, slots - filled))
    }

    static func progressSegments(
        forPercentText percentText: String,
        overrunPercent: Double? = nil,
        usedPercent: Double? = nil,
        thresholdPercent: Double? = nil,
        slots: Int = 18
    ) -> (filled: Int, exceeded: Int, empty: Int) {
        guard let percent = Int(
            percentText
                .replacingOccurrences(of: "%", with: "")
                .replacingOccurrences(of: "!", with: "")
        ) else {
            return (0, 0, slots)
        }

        if let usedPercent, let thresholdPercent, usedPercent > thresholdPercent {
            let withinPaceSlots = max(0, min(slots, Int((min(usedPercent, thresholdPercent) / 100.0 * Double(slots)).rounded())))
            let totalUsedSlots = max(withinPaceSlots, min(slots, Int((usedPercent / 100.0 * Double(slots)).rounded())))
            let exceeded = max(0, min(slots - withinPaceSlots, totalUsedSlots - withinPaceSlots))
            let empty = max(0, slots - withinPaceSlots - exceeded)
            return (withinPaceSlots, exceeded, empty)
        }

        let filled = max(0, min(slots, Int((Double(percent) / 100.0 * Double(slots)).rounded())))
        let empty = max(0, slots - filled)
        let exceededSlots = Int((((overrunPercent ?? 0) / 100.0) * Double(slots)).rounded())
        let exceeded = min(empty, max(0, exceededSlots))
        return (filled, exceeded, max(0, empty - exceeded))
    }
}
