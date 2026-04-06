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

    var activeDaysPerWeek: Int {
        switch self {
        case .workWeek40:
            return 5
        case .balanced56, .heavy70:
            return 7
        }
    }

    var dailyActiveHours: Double {
        switch self {
        case .workWeek40:
            return 8
        case .balanced56:
            return 8
        case .heavy70:
            return 10
        }
    }

    var displayScale: Double {
        Double(weeklyHours) / 70.0
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
        language == .english ? "Uses a \(activeDaysPerWeek)-day schedule at \(Int(dailyActiveHours))h/day to place the weekly marker and pace warnings." : "按每周 \(activeDaysPerWeek) 天、每天 \(Int(dailyActiveHours)) 小时的节奏来计算每周箭头和提醒。"
    }

    func detailedTooltipText(language: AppLanguage = .english) -> String {
        language == .english ? "\(tooltipText(language: language)) \(summary(language: language)) This changes the weekly normal-progress marker and pace alerts, but never changes % left." : "\(tooltipText(language: language)) \(summary(language: language)) 它会影响每周的正常进度箭头和节奏提醒，但不会改变剩余百分比。"
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
        language == .english ? "40h uses 5 days × 8h. 56h uses 7 days × 8h. 70h uses 7 days × 10h. % left never changes." : "40 小时按 5 天 × 8 小时算，56 小时按 7 天 × 8 小时算，70 小时按 7 天 × 10 小时算。剩余百分比不会变化。"
    }

    static func menuWindowTitle(for label: String) -> String {
        label
    }

    static func weeklyPaceExplanation(for mode: WeeklyPacingMode, language: AppLanguage = .english) -> String {
        language == .english ? "! means weekly usage is ahead of the average pace implied by \(mode.weeklyHours)/week. This preset changes the weekly marker position and alert severity, but never changes % left." : "! 表示每周使用速度超过了 \(mode.weeklyHours) 小时/周这条平均节奏线。这个档位会影响每周箭头位置和提醒严重程度，但不会改变剩余百分比。"
    }

    static func weeklyPaceInlineExplanation(for mode: WeeklyPacingMode, language: AppLanguage = .english) -> String {
        language == .english
            ? "Weekly marker and ! use \(mode.activeDaysPerWeek)d × \(Int(mode.dailyActiveHours))h for \(mode.weeklyHours)h/week."
            : "每周箭头和 ! 按 \(mode.activeDaysPerWeek) 天 × \(Int(mode.dailyActiveHours)) 小时来计算 \(mode.weeklyHours) 小时/周。"
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
        usedOnLeft: Bool = false,
        scale: Double = 1.0,
        slots: Int = 18
    ) -> (remaining: Int, used: Int, markerIndex: Int?, totalSlots: Int) {
        let activeSlots = max(1, min(slots, Int((Double(slots) * scale).rounded())))
        guard let percent = Int(
            percentText
                .replacingOccurrences(of: "%", with: "")
                .replacingOccurrences(of: "!", with: "")
        ) else {
            return (0, activeSlots, nil, activeSlots)
        }

        let remaining = max(0, min(activeSlots, Int((Double(percent) / 100.0 * Double(activeSlots)).rounded())))
        let used = max(0, activeSlots - remaining)
        let markerIndex: Int?
        if let thresholdPercent {
            let expectedPercent = usedOnLeft
                ? max(0, min(100, thresholdPercent))
                : max(0, min(100, 100.0 - thresholdPercent))
            markerIndex = max(0, min(activeSlots, Int((expectedPercent / 100.0 * Double(activeSlots)).rounded())))
        } else {
            markerIndex = nil
        }
        return (remaining, used, markerIndex, activeSlots)
    }
}
