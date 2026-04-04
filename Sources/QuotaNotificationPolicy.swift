import Foundation

enum QuotaNotificationLevel: Equatable {
    case none
    case warning
    case critical
}

struct QuotaNotificationSnapshot: Equatable {
    let sessionLevel: QuotaNotificationLevel
    let weeklyLevel: QuotaNotificationLevel
    let paceLevel: QuotaNotificationLevel
    let sessionResetSoon: Bool
    let weeklyResetSoon: Bool
}

struct QuotaNotificationEvent: Equatable {
    let title: String
    let body: String
}

enum QuotaNotificationPolicy {
    private static let sessionResetThreshold: TimeInterval = 15 * 60
    private static let weeklyResetThreshold: TimeInterval = 12 * 60 * 60

    static func snapshot(from presentation: StatusPresentation) -> QuotaNotificationSnapshot {
        QuotaNotificationSnapshot(
            sessionLevel: level(for: presentation.primaryRow?.percentText),
            weeklyLevel: level(for: presentation.secondaryRow?.percentText),
            paceLevel: paceLevel(for: presentation),
            sessionResetSoon: resetSoon(for: presentation.primaryRow?.resetDate, threshold: sessionResetThreshold),
            weeklyResetSoon: resetSoon(for: presentation.secondaryRow?.resetDate, threshold: weeklyResetThreshold)
        )
    }

    static func nextEvent(
        previous: QuotaNotificationSnapshot?,
        current: QuotaNotificationSnapshot,
        presentation: StatusPresentation
    ) -> QuotaNotificationEvent? {
        let previousSession = previous?.sessionLevel ?? .none
        let previousWeekly = previous?.weeklyLevel ?? .none
        let previousPace = previous?.paceLevel ?? .none
        let previousSessionResetSoon = previous?.sessionResetSoon ?? false
        let previousWeeklyResetSoon = previous?.weeklyResetSoon ?? false

        if current.sessionLevel == .critical, previousSession != .critical {
            return QuotaNotificationEvent(
                title: "5-hour quota is low",
                body: "Session remaining dropped below 30%."
            )
        }
        if current.sessionLevel == .warning, previousSession == .none {
            return QuotaNotificationEvent(
                title: "5-hour quota warning",
                body: "Session remaining dropped below 50%."
            )
        }
        if current.weeklyLevel == .critical, previousWeekly != .critical {
            return QuotaNotificationEvent(
                title: "7-day quota is low",
                body: "Weekly remaining dropped below 30%."
            )
        }
        if current.weeklyLevel == .warning, previousWeekly == .none {
            return QuotaNotificationEvent(
                title: "7-day quota warning",
                body: "Weekly remaining dropped below 50%."
            )
        }
        if current.paceLevel == .critical, previousPace != .critical {
            return QuotaNotificationEvent(
                title: "Usage pace is too fast",
                body: presentation.paceMessage.map { "\($0). Slow down to avoid running out early." } ?? "Quota usage is well above your selected pace."
            )
        }
        if current.paceLevel == .warning, previousPace == .none {
            return QuotaNotificationEvent(
                title: "Usage pace warning",
                body: presentation.paceMessage.map { "\($0)." } ?? "Quota usage is ahead of your selected pace."
            )
        }
        if current.sessionResetSoon, !previousSessionResetSoon {
            return QuotaNotificationEvent(
                title: "5-hour window resets soon",
                body: "The 5-hour quota window resets in less than 15 minutes."
            )
        }
        if current.weeklyResetSoon, !previousWeeklyResetSoon {
            return QuotaNotificationEvent(
                title: "7-day window resets soon",
                body: "The 7-day quota window resets in less than 12 hours."
            )
        }
        return nil
    }

    private static func level(for percentText: String?) -> QuotaNotificationLevel {
        guard let percentText else { return .none }
        switch QuotaDisplayPolicy.colorLevel(forPercentText: percentText) {
        case .critical:
            return .critical
        case .warning:
            return .warning
        default:
            return .none
        }
    }

    private static func paceLevel(for presentation: StatusPresentation) -> QuotaNotificationLevel {
        switch presentation.paceSeverity {
        case .critical:
            return .critical
        case .warning:
            return .warning
        case nil:
            return .none
        }
    }

    private static func resetSoon(for date: Date?, threshold: TimeInterval, now: Date = Date()) -> Bool {
        guard let date else { return false }
        let remaining = date.timeIntervalSince(now)
        return remaining > 0 && remaining <= threshold
    }
}
