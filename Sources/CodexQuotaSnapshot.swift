import Foundation

struct CodexQuotaSnapshot: Decodable {
    let planType: String?
    let rateLimits: RateLimits

    enum CodingKeys: String, CodingKey {
        case planType = "plan_type"
        case rateLimits = "rate_limits"
    }
}

struct RateLimits: Decodable {
    let allowed: Bool?
    let limitReached: Bool?
    let primary: LimitWindow?
    let secondary: LimitWindow?

    enum CodingKeys: String, CodingKey {
        case allowed
        case limitReached = "limit_reached"
        case primary
        case secondary
    }
}

struct LimitWindow: Decodable {
    let usedPercent: Double
    let windowMinutes: Int?
    let resetAfterSeconds: Int?
    let resetAt: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case windowMinutes = "window_minutes"
        case resetAfterSeconds = "reset_after_seconds"
        case resetAt = "reset_at"
    }

    var remainingPercent: Int {
        max(0, min(100, Int((100.0 - usedPercent).rounded())))
    }

    var resetDate: Date? {
        guard let resetAt else { return nil }
        return Date(timeIntervalSince1970: resetAt)
    }

    var usedRoundedPercent: Int {
        max(0, min(100, Int(usedPercent.rounded())))
    }

    var elapsedFraction: Double? {
        guard let windowMinutes, let resetAfterSeconds else { return nil }
        let totalSeconds = Double(windowMinutes * 60)
        guard totalSeconds > 0 else { return nil }
        let remainingSeconds = min(max(Double(resetAfterSeconds), 0), totalSeconds)
        let elapsedSeconds = totalSeconds - remainingSeconds
        return min(max(elapsedSeconds / totalSeconds, 0), 1)
    }

    var isUsingFasterThanAverage: Bool {
        guard let elapsedFraction else { return false }
        return usedPercent > elapsedFraction * 100.0
    }
}

struct StatusPresentation {
    struct AccountRow {
        let label: String
        let value: String
    }

    struct MenuRow {
        let label: String
        let percentText: String
        let resetText: String
        let isUsingFasterThanAverage: Bool
    }

    let line1: String
    let line2: String
    let tooltip: String
    let accountRow: AccountRow?
    let planRow: AccountRow?
    let primaryRow: MenuRow?
    let secondaryRow: MenuRow?
    let paceMessage: String?

    init(
        line1: String,
        line2: String,
        tooltip: String,
        accountRow: AccountRow? = nil,
        planRow: AccountRow? = nil,
        primaryRow: MenuRow? = nil,
        secondaryRow: MenuRow? = nil,
        paceMessage: String? = nil
    ) {
        self.line1 = line1
        self.line2 = line2
        self.tooltip = tooltip
        self.accountRow = accountRow
        self.planRow = planRow
        self.primaryRow = primaryRow
        self.secondaryRow = secondaryRow
        self.paceMessage = paceMessage
    }

    static let loading = StatusPresentation(
        line1: "H --",
        line2: "W --",
        tooltip: "Loading Codex limits..."
    )

    static func unavailable(_ reason: String) -> StatusPresentation {
        StatusPresentation(
            line1: "H --",
            line2: "W --",
            tooltip: reason,
            paceMessage: nil
        )
    }

    init(snapshot: CodexQuotaSnapshot, accountInfo: CodexAccountInfo?, generatedAt: Date) {
        let primary = snapshot.rateLimits.primary
        let secondary = snapshot.rateLimits.secondary

        line1 = primary.map { "H \(StatusPresentation.statusPercentText(for: $0))" } ?? "H --"
        line2 = secondary.map { "W \(StatusPresentation.statusPercentText(for: $0))" } ?? "W --"
        accountRow = accountInfo.map {
            AccountRow(label: "Account", value: $0.displayName)
        }
        planRow = accountInfo.map {
            AccountRow(label: "Plan", value: $0.planDisplayName)
        }
        primaryRow = primary.map {
            MenuRow(
                label: StatusPresentation.windowLabel(for: $0),
                percentText: StatusPresentation.statusPercentText(for: $0),
                resetText: StatusPresentation.resetLabel(for: $0),
                isUsingFasterThanAverage: $0.isUsingFasterThanAverage
            )
        }
        secondaryRow = secondary.map {
            MenuRow(
                label: StatusPresentation.windowLabel(for: $0),
                percentText: StatusPresentation.statusPercentText(for: $0),
                resetText: StatusPresentation.resetLabel(for: $0),
                isUsingFasterThanAverage: $0.isUsingFasterThanAverage
            )
        }
        paceMessage = StatusPresentation.paceMessage(primary: primary, secondary: secondary)

        var parts: [String] = []
        if let accountInfo {
            parts.append("Account: \(accountInfo.displayName)")
            if let email = accountInfo.email {
                parts.append("Email: \(email)")
            }
            parts.append("Plan: \(accountInfo.planDisplayName)")
        }
        if let plan = snapshot.planType {
            parts.append("Plan: \(plan)")
        }
        if let primary {
            parts.append("Primary remaining: \(StatusPresentation.statusPercentText(for: primary))")
            if let date = primary.resetDate {
                parts.append("Primary resets: \(StatusPresentation.dateFormatter.string(from: date))")
            }
            if primary.isUsingFasterThanAverage, let elapsedFraction = primary.elapsedFraction {
                parts.append("Primary pace: above average for this window (\(Int((elapsedFraction * 100).rounded()))% of time elapsed, \(primary.usedRoundedPercent)% used)")
            }
        }
        if let secondary {
            parts.append("Weekly remaining: \(StatusPresentation.statusPercentText(for: secondary))")
            if let date = secondary.resetDate {
                parts.append("Weekly resets: \(StatusPresentation.dateFormatter.string(from: date))")
            }
            if secondary.isUsingFasterThanAverage, let elapsedFraction = secondary.elapsedFraction {
                parts.append("Weekly pace: above average for this window (\(Int((elapsedFraction * 100).rounded()))% of time elapsed, \(secondary.usedRoundedPercent)% used)")
            }
        }
        if let paceMessage {
            parts.append("Pace alert: \(paceMessage)")
        }
        parts.append("Updated: \(StatusPresentation.dateFormatter.string(from: generatedAt))")
        tooltip = parts.joined(separator: "\n")
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter
    }()

    private static func windowLabel(for window: LimitWindow) -> String {
        switch window.windowMinutes {
        case 300:
            return "5 hours"
        case 10080:
            return "1 week"
        case let minutes?:
            if minutes % 1440 == 0 {
                return "\(minutes / 1440) days"
            }
            if minutes % 60 == 0 {
                return "\(minutes / 60) hours"
            }
            return "\(minutes) min"
        case nil:
            return "Window"
        }
    }

    private static func resetLabel(for window: LimitWindow) -> String {
        guard let date = window.resetDate else { return "--" }
        if let minutes = window.windowMinutes, minutes <= 1440 {
            return timeFormatter.string(from: date)
        }
        return shortDateFormatter.string(from: date)
    }

    private static func statusPercentText(for window: LimitWindow) -> String {
        "\(window.remainingPercent)%\(window.isUsingFasterThanAverage ? "!" : "")"
    }

    private static func paceMessage(primary: LimitWindow?, secondary: LimitWindow?) -> String? {
        var labels: [String] = []
        if let primary, primary.isUsingFasterThanAverage {
            labels.append(windowLabel(for: primary))
        }
        if let secondary, secondary.isUsingFasterThanAverage {
            labels.append(windowLabel(for: secondary))
        }

        guard !labels.isEmpty else { return nil }
        if labels.count == 1 {
            return "\(labels[0]) usage is above the current window average"
        }
        return labels.joined(separator: " + ") + " usage is above the current window average"
    }
}
