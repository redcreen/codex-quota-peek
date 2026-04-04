import Foundation

enum QuotaRefreshPolicy {
    private static let apiProtectionWindow: TimeInterval = 120

    static func preferredResult(
        fetchedResult: CodexQuotaFetchResult,
        mode: QuotaRefreshMode,
        lastSuccessfulAPIResult: CodexQuotaFetchResult?
    ) -> CodexQuotaFetchResult {
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
        guard let api else { return false }
        guard let fetched else { return true }

        if let fetchedResetAt = fetched.resetAt, let apiResetAt = api.resetAt, fetchedResetAt < apiResetAt {
            return true
        }

        return false
    }
}

enum QuotaRefreshMode {
    case automatic
    case apiManual
}
