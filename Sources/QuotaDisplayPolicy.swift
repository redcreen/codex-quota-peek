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
            return "Light"
        case .balanced56:
            return "Balanced"
        case .heavy70:
            return "Heavy"
        }
    }

    var menuTitle: String {
        "\(label) · \(title)"
    }

    func tooltipText() -> String {
        "Weekly pace compares your usage against a \(weeklyHours)-hour work week."
    }
}

enum QuotaDisplayPolicy {
    static func menuWindowTitle(for label: String) -> String {
        label
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
