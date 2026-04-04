import Foundation

enum QuotaDisplayColorLevel {
    case normal
    case warning
    case critical
}

enum QuotaDisplayPolicy {
    static func menuWindowTitle(for label: String) -> String {
        switch label {
        case "5 hours":
            return "Session"
        case "1 week":
            return "Weekly"
        default:
            return label
        }
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
}
