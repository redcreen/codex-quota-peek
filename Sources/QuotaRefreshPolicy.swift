import Foundation

enum QuotaSourceStrategy: String, CaseIterable {
    case auto
    case preferAPI
    case preferLocalLogs

    var title: String {
        switch self {
        case .auto:
            return "Auto"
        case .preferAPI:
            return "Prefer API"
        case .preferLocalLogs:
            return "Prefer local logs"
        }
    }

    var summary: String {
        switch self {
        case .auto:
            return "Balanced default. Auto refresh follows local logs, while startup and manual refresh prefer the API."
        case .preferAPI:
            return "Freshness first. Automatic refresh tries the official API before falling back."
        case .preferLocalLogs:
            return "Most conservative. Background and startup refresh stay on local Codex logs whenever possible."
        }
    }
}

enum QuotaFetchPlan {
    case localFirst
    case apiPreferred
}

enum QuotaRefreshPolicy {
    private static let apiProtectionWindow: TimeInterval = 120

    static func fetchPlan(for mode: QuotaRefreshMode, sourceStrategy: QuotaSourceStrategy) -> QuotaFetchPlan {
        switch mode {
        case .apiManual:
            return .apiPreferred
        case .startupAPI:
            return sourceStrategy == .preferLocalLogs ? .localFirst : .apiPreferred
        case .automatic:
            return sourceStrategy == .preferAPI ? .apiPreferred : .localFirst
        }
    }

    static func preferredResult(
        fetchedResult: CodexQuotaFetchResult,
        mode: QuotaRefreshMode,
        lastSuccessfulAPIResult: CodexQuotaFetchResult?,
        lastAcceptedResult: CodexQuotaFetchResult?
    ) -> CodexQuotaFetchResult {
        if let lastAcceptedResult, shouldKeepLastAccepted(lastAcceptedResult, over: fetchedResult) {
            return lastAcceptedResult
        }

        if fetchedResult.source == .api {
            return fetchedResult
        }

        guard mode == .automatic, let recentAPI = lastSuccessfulAPIResult else {
            return fetchedResult
        }

        let fetchedDate = fetchedResult.sourceDate ?? .distantPast
        let apiDate = recentAPI.sourceDate ?? .distantPast
        if fetchedDate < apiDate {
            return recentAPI
        }

        if shouldPreferAPIResult(recentAPI, over: fetchedResult) {
            return recentAPI
        }

        return fetchedResult
    }

    private static func shouldKeepLastAccepted(
        _ lastAcceptedResult: CodexQuotaFetchResult,
        over fetchedResult: CodexQuotaFetchResult
    ) -> Bool {
        snapshotLooksStale(
            fetchedResult.snapshot.rateLimits.primary,
            comparedTo: lastAcceptedResult.snapshot.rateLimits.primary
        ) || snapshotLooksStale(
            fetchedResult.snapshot.rateLimits.secondary,
            comparedTo: lastAcceptedResult.snapshot.rateLimits.secondary
        )
    }

    private static func shouldPreferAPIResult(
        _ apiResult: CodexQuotaFetchResult,
        over fetchedResult: CodexQuotaFetchResult
    ) -> Bool {
        guard let apiDate = apiResult.sourceDate,
              Date().timeIntervalSince(apiDate) <= apiProtectionWindow else {
            return false
        }

        return windowLooksStale(fetchedResult.snapshot.rateLimits.primary, comparedTo: apiResult.snapshot.rateLimits.primary)
            || windowLooksStale(fetchedResult.snapshot.rateLimits.secondary, comparedTo: apiResult.snapshot.rateLimits.secondary)
    }

    private static func windowLooksStale(_ fetched: LimitWindow?, comparedTo api: LimitWindow?) -> Bool {
        snapshotLooksStale(fetched, comparedTo: api)
    }

    private static func snapshotLooksStale(_ fetched: LimitWindow?, comparedTo current: LimitWindow?) -> Bool {
        guard let current else { return false }
        guard let fetched else { return true }

        if let fetchedResetAt = fetched.resetAt, let currentResetAt = current.resetAt {
            if fetchedResetAt < currentResetAt {
                return true
            }
            if fetchedResetAt > currentResetAt {
                return false
            }
        }

        return fetched.remainingPercent > current.remainingPercent
    }
}

enum QuotaRefreshMode {
    case automatic
    case apiManual
    case startupAPI
}
