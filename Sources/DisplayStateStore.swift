import Foundation

struct DisplayStateStore {
    private(set) var lastSuccessfulAPIResult: CodexQuotaFetchResult?
    private(set) var lastAcceptedResult: CodexQuotaFetchResult?
    private(set) var snapshotForDisplay: CodexQuotaSnapshot?
    private(set) var accountInfoForDisplay: CodexAccountInfo?
    private(set) var trendSummaryForDisplay: CodexQuotaTrendSummary?
    private(set) var sourceForDisplay: CodexQuotaFetchSource?
    private(set) var generatedAtForDisplay: Date?

    mutating func resolvePreferredResult(
        _ fetchedResult: CodexQuotaFetchResult,
        mode: QuotaRefreshMode
    ) -> CodexQuotaFetchResult {
        let preferred = QuotaRefreshPolicy.preferredResult(
            fetchedResult: fetchedResult,
            mode: mode,
            lastSuccessfulAPIResult: lastSuccessfulAPIResult,
            lastAcceptedResult: lastAcceptedResult
        )
        if fetchedResult.source == .api {
            lastSuccessfulAPIResult = fetchedResult
        }
        lastAcceptedResult = preferred
        return preferred
    }

    mutating func recordDisplayInputs(
        snapshot: CodexQuotaSnapshot,
        accountInfo: CodexAccountInfo?,
        trendSummary: CodexQuotaTrendSummary?,
        source: CodexQuotaFetchSource,
        generatedAt: Date
    ) {
        snapshotForDisplay = snapshot
        accountInfoForDisplay = accountInfo
        trendSummaryForDisplay = trendSummary
        sourceForDisplay = source
        generatedAtForDisplay = generatedAt
    }

    var hasDisplaySnapshot: Bool {
        snapshotForDisplay != nil
    }

    func rebuildPresentation(
        weeklyPacingMode: WeeklyPacingMode,
        language: AppLanguage
    ) -> StatusPresentation? {
        guard
            let snapshot = snapshotForDisplay,
            let source = sourceForDisplay,
            let generatedAt = generatedAtForDisplay
        else {
            return nil
        }

        return StatusPresentation(
            snapshot: snapshot,
            accountInfo: accountInfoForDisplay,
            generatedAt: generatedAt,
            source: source,
            trendSummary: trendSummaryForDisplay,
            weeklyPacingMode: weeklyPacingMode,
            language: language
        )
    }
}
