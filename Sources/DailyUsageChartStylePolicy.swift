import Foundation

enum DailyUsageChartTone {
    case muted
    case normal
    case alert
}

enum DailyUsageChartStylePolicy {
    static func barTone(isFilled: Bool, isAheadOfPace: Bool, isFuture: Bool) -> DailyUsageChartTone {
        guard isFilled else { return .muted }
        if isFuture { return .muted }
        if isAheadOfPace { return .alert }
        return .normal
    }

    static func footerTone(isAheadOfPace: Bool, isFuture: Bool) -> DailyUsageChartTone {
        if isFuture { return .muted }
        if isAheadOfPace { return .alert }
        return .normal
    }
}
