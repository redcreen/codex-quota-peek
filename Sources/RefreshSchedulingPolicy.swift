import Foundation

enum RefreshSchedulingPolicy {
    private static let manualRefreshBlockTimeout: TimeInterval = 30

    static func shouldStart(
        mode: QuotaRefreshMode,
        manualRefreshStartedAt: Date?,
        now: Date = Date()
    ) -> Bool {
        guard let manualRefreshStartedAt else { return true }
        guard now.timeIntervalSince(manualRefreshStartedAt) < manualRefreshBlockTimeout else {
            return true
        }
        switch mode {
        case .apiManual:
            return true
        case .automatic, .startupAPI:
            return false
        }
    }
}
