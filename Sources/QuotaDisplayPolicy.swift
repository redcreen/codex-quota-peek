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
        switch self {
        case .workWeek40:
            return "Standard"
        case .balanced56:
            return "Balanced"
        case .heavy70:
            return "Heavy"
        }
    }

    var menuTitle: String {
        "\(label) · \(title)"
    }

    var summary: String {
        switch self {
        case .workWeek40:
            return "Most sensitive. ! appears sooner."
        case .balanced56:
            return "Balanced pace alerts."
        case .heavy70:
            return "Least sensitive. ! appears later."
        }
    }

    func tooltipText() -> String {
        "Compares weekly used % against a \(weeklyHours)-hour work week."
    }

    func detailedTooltipText() -> String {
        "\(tooltipText()) \(summary) This only affects ! pace alerts, not % left."
    }
}

enum QuotaDisplayPolicy {
    static let weeklyPacingSectionTitle = "Weekly ! Alert"
    static let weeklyPacingHintTitle = "! appears when weekly usage is ahead of your selected pace."
    static let weeklyPacingHintDetail = "40h warns sooner. 70h warns later. % left never changes."

    static func menuWindowTitle(for label: String) -> String {
        label
    }

    static func weeklyPaceExplanation(for mode: WeeklyPacingMode) -> String {
        "! means weekly usage is ahead of your selected pace. We compare used % against how much of a \(mode.weeklyHours)-hour work week has elapsed. This only changes the weekly ! warning, not % left."
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
