import Foundation

struct DisplayStateStore {
    private struct DisplaySignature: Equatable {
        let primaryRemainingPercent: Int?
        let primaryResetAt: Int?
        let secondaryRemainingPercent: Int?
        let secondaryResetAt: Int?
        let creditsBalance: String?
        let creditsHasCredits: Bool?
        let creditsUnlimited: Bool?
    }

    private(set) var lastSuccessfulAPIResult: CodexQuotaFetchResult?
    private(set) var lastAcceptedResult: CodexQuotaFetchResult?
    private(set) var snapshotForDisplay: CodexQuotaSnapshot?
    private(set) var accountInfoForDisplay: CodexAccountInfo?
    private(set) var trendSummaryForDisplay: CodexQuotaTrendSummary?
    private(set) var sourceForDisplay: CodexQuotaFetchSource?
    private(set) var generatedAtForDisplay: Date?
    private var displaySignature: DisplaySignature?

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
        generatedAt: Date,
        forceFreshnessUpdate: Bool = false
    ) -> Date {
        let signature = makeDisplaySignature(from: snapshot)
        snapshotForDisplay = snapshot
        accountInfoForDisplay = accountInfo
        trendSummaryForDisplay = trendSummary
        sourceForDisplay = source
        if forceFreshnessUpdate || displaySignature != signature || generatedAtForDisplay == nil {
            generatedAtForDisplay = generatedAt
            displaySignature = signature
        }
        return generatedAtForDisplay ?? generatedAt
    }

    var hasDisplaySnapshot: Bool {
        snapshotForDisplay != nil
    }

    var displayedSource: CodexQuotaFetchSource? {
        sourceForDisplay
    }

    var displayedGeneratedAt: Date? {
        generatedAtForDisplay
    }

    func rebuildPresentation(
        weeklyPacingMode: WeeklyPacingMode,
        language: AppLanguage,
        now: Date = Date()
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
            language: language,
            now: now
        )
    }

    private func makeDisplaySignature(from snapshot: CodexQuotaSnapshot) -> DisplaySignature {
        DisplaySignature(
            primaryRemainingPercent: snapshot.rateLimits.primary?.remainingPercent,
            primaryResetAt: snapshot.rateLimits.primary?.resetAt.map { Int($0.rounded()) },
            secondaryRemainingPercent: snapshot.rateLimits.secondary?.remainingPercent,
            secondaryResetAt: snapshot.rateLimits.secondary?.resetAt.map { Int($0.rounded()) },
            creditsBalance: snapshot.credits?.balance,
            creditsHasCredits: snapshot.credits?.hasCredits,
            creditsUnlimited: snapshot.credits?.unlimited
        )
    }
}
