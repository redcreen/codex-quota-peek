import Foundation

enum RefreshSchedulingPolicy {
    static func shouldStart(mode: QuotaRefreshMode, manualRefreshInFlight: Bool) -> Bool {
        guard manualRefreshInFlight else { return true }
        switch mode {
        case .apiManual:
            return true
        case .automatic, .startupAPI:
            return false
        }
    }
}
