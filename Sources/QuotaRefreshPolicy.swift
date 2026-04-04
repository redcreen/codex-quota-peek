import Foundation

enum QuotaRefreshPolicy {
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

        return fetchedResult
    }
}

enum QuotaRefreshMode {
    case automatic
    case apiManual
}
