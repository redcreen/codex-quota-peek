import Foundation

enum QuotaSourceStrategy: String, CaseIterable {
    case auto
    case preferAPI
    case preferLocalLogs

    var title: String {
        title(language: .english)
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .auto:
            return language == .english ? "Auto" : "自动"
        case .preferAPI:
            return language == .english ? "Prefer API" : "优先 API"
        case .preferLocalLogs:
            return language == .english ? "Prefer local logs" : "优先本地日志"
        }
    }

    var summary: String {
        summary(language: .english)
    }

    func summary(language: AppLanguage) -> String {
        switch self {
        case .auto:
            return language == .english ? "Balanced default. Auto refresh follows local logs, while startup and manual refresh prefer the API." : "平衡的默认策略。自动刷新跟随本地日志，而启动和手动刷新更偏向 API。"
        case .preferAPI:
            return language == .english ? "Freshness first. Automatic refresh tries the official API before falling back." : "最新优先。自动刷新会先尝试官方 API，再回退。"
        case .preferLocalLogs:
            return language == .english ? "Most conservative. Background and startup refresh stay on local Codex logs whenever possible." : "最保守。后台和启动刷新会尽量留在本地 Codex 日志。"
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
            return .apiPreferred
        case .automatic:
            return sourceStrategy == .preferAPI ? .apiPreferred : .localFirst
        }
    }

    static func shouldPreferAPIMenuOpenRefresh(
        lastSource: CodexQuotaFetchSource?,
        lastGeneratedAt: Date?,
        now: Date = Date()
    ) -> Bool {
        guard let lastSource else { return true }
        if lastSource != .api {
            return true
        }
        guard let lastGeneratedAt else { return true }
        return now.timeIntervalSince(lastGeneratedAt) > apiProtectionWindow
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
