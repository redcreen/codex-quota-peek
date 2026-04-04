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
            return language == .english ? "Most sensitive. ! appears sooner." : "最敏感。! 会更早出现。"
        case .balanced56:
            return language == .english ? "Balanced pace alerts." : "平衡的节奏提醒。"
        case .heavy70:
            return language == .english ? "Least sensitive. ! appears later." : "最宽松。! 会更晚出现。"
        }
    }

    func tooltipText(language: AppLanguage = .english) -> String {
        language == .english ? "Compares weekly used % against a \(weeklyHours)-hour work week." : "把每周已用百分比与 \(weeklyHours) 小时工作周进行比较。"
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
        language == .english ? "! means weekly usage is ahead of your selected pace. We compare used % against how much of a \(mode.weeklyHours)-hour work week has elapsed. This only changes the weekly ! warning, not % left." : "! 表示每周使用速度超过了你选择的节奏。我们会把已用百分比，与一个 \(mode.weeklyHours) 小时工作周中已过去的比例进行比较。这只会影响每周 ! 提醒，不会改变剩余百分比。"
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

    static func progressSegments(forPercentText percentText: String, slots: Int = 18) -> (filled: Int, exceeded: Int, empty: Int) {
        guard let percent = Int(
            percentText
                .replacingOccurrences(of: "%", with: "")
                .replacingOccurrences(of: "!", with: "")
        ) else {
            return (0, 0, slots)
        }

        let filled = max(0, min(slots, Int((Double(percent) / 100.0 * Double(slots)).rounded())))
        let markerCount = percentText.filter { $0 == "!" }.count
        let empty = max(0, slots - filled)
        let exceeded = min(empty, markerCount)
        return (filled, exceeded, max(0, empty - exceeded))
    }
}
