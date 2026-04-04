import Foundation

enum QuotaDisplayColorLevel {
    case normal
    case warning
    case critical
}

enum WeeklyPacingMode: String, CaseIterable {
    case fullWeek24x7
    case activeHoursCustom

    var title: String {
        switch self {
        case .fullWeek24x7:
            return "Full week (24h/day)"
        case .activeHoursCustom:
            return "Active time (custom)"
        }
    }

    func tooltipText(activeHoursPerDay: Int) -> String {
        switch self {
        case .fullWeek24x7:
            return "Weekly pace compares your usage against a full 7-day, 24-hour week."
        case .activeHoursCustom:
            return "Weekly pace compares your usage against \(activeHoursPerDay) active hours per day across 7 days."
        }
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
