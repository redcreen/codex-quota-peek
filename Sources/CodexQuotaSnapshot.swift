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
}

struct StatusPresentation {
    let line1: String
    let line2: String
    let tooltip: String

    init(line1: String, line2: String, tooltip: String) {
        self.line1 = line1
        self.line2 = line2
        self.tooltip = tooltip
    }

    static let loading = StatusPresentation(
        line1: "P --",
        line2: "W --",
        tooltip: "Loading Codex limits..."
    )

    static func unavailable(_ reason: String) -> StatusPresentation {
        StatusPresentation(
            line1: "P --",
            line2: "W --",
            tooltip: reason
        )
    }

    init(snapshot: CodexQuotaSnapshot, generatedAt: Date) {
        let primary = snapshot.rateLimits.primary
        let secondary = snapshot.rateLimits.secondary

        line1 = primary.map { "P \($0.remainingPercent)%" } ?? "P --"
        line2 = secondary.map { "W \($0.remainingPercent)%" } ?? "W --"

        var parts: [String] = []
        if let plan = snapshot.planType {
            parts.append("Plan: \(plan)")
        }
        if let primary {
            parts.append("Primary remaining: \(primary.remainingPercent)%")
            if let date = primary.resetDate {
                parts.append("Primary resets: \(StatusPresentation.dateFormatter.string(from: date))")
            }
        }
        if let secondary {
            parts.append("Weekly remaining: \(secondary.remainingPercent)%")
            if let date = secondary.resetDate {
                parts.append("Weekly resets: \(StatusPresentation.dateFormatter.string(from: date))")
            }
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
}
