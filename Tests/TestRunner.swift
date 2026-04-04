import Foundation

@discardableResult
func expect(_ condition: @autoclosure () -> Bool, _ message: String) -> Bool {
    if condition() {
        print("PASS: \(message)")
        return true
    }

    fputs("FAIL: \(message)\n", stderr)
    exit(1)
}

func makeWindow(usedPercent: Double, windowMinutes: Int = 300, resetAfterSeconds: Int = 120, resetAt: TimeInterval = 1_775_291_731) -> LimitWindow {
    LimitWindow(
        usedPercent: usedPercent,
        windowMinutes: windowMinutes,
        resetAfterSeconds: resetAfterSeconds,
        resetAt: resetAt
    )
}

func makeSnapshot(primaryUsed: Double, secondaryUsed: Double) -> CodexQuotaSnapshot {
    CodexQuotaSnapshot(
        planType: "pro",
        rateLimits: RateLimits(
            allowed: true,
            limitReached: false,
            primary: makeWindow(usedPercent: primaryUsed, windowMinutes: 300),
            secondary: makeWindow(usedPercent: secondaryUsed, windowMinutes: 10080)
        )
    )
}

func makeResult(source: CodexQuotaFetchSource, sourceDate: Date?, primaryUsed: Double, secondaryUsed: Double) -> CodexQuotaFetchResult {
    CodexQuotaFetchResult(
        snapshot: makeSnapshot(primaryUsed: primaryUsed, secondaryUsed: secondaryUsed),
        source: source,
        sourceDate: sourceDate
    )
}

func testRealtimeLogRowParsingUsesSQLitePipeSeparator() {
    let row = #"1775291731|session_loop: websocket event: {"type":"codex.rate_limits","rate_limits":{"primary":{"used_percent":5,"window_minutes":300,"reset_after_seconds":120,"reset_at":1775292000},"secondary":{"used_percent":8,"window_minutes":10080,"reset_after_seconds":3600,"reset_at":1775896800}},"plan_type":"pro"}"#
    let parsed = CodexQuotaProvider.parseRealtimeLogRow(row)

    expect(parsed != nil, "sqlite pipe-delimited realtime log row parses")
    expect(parsed?.source == .realtimeLogs, "parsed row is marked as local logs")
    expect(parsed?.sourceDate?.timeIntervalSince1970 == 1_775_291_731, "parsed row keeps log timestamp")
    expect(parsed?.snapshot.rateLimits.primary?.remainingPercent == 95, "parsed row keeps primary remaining percent")
    expect(parsed?.snapshot.rateLimits.secondary?.remainingPercent == 92, "parsed row keeps secondary remaining percent")
}

func testAutomaticRefreshPrefersRecentAPIOverOlderLogs() {
    let recentAPI = makeResult(
        source: .api,
        sourceDate: Date(timeIntervalSince1970: 2_000),
        primaryUsed: 5,
        secondaryUsed: 8
    )
    let staleLogs = makeResult(
        source: .realtimeLogs,
        sourceDate: Date(timeIntervalSince1970: 1_900),
        primaryUsed: 18,
        secondaryUsed: 12
    )

    let preferred = QuotaRefreshPolicy.preferredResult(
        fetchedResult: staleLogs,
        mode: .automatic,
        lastSuccessfulAPIResult: recentAPI
    )

    expect(preferred.source == .api, "automatic refresh keeps newer API snapshot over stale logs")
    expect(preferred.snapshot.rateLimits.primary?.remainingPercent == 95, "preferred result keeps API quota values")
}

func testAutomaticRefreshAllowsLogsAfterTheyCatchUp() {
    let recentAPI = makeResult(
        source: .api,
        sourceDate: Date(timeIntervalSince1970: 2_000),
        primaryUsed: 5,
        secondaryUsed: 8
    )
    let freshLogs = makeResult(
        source: .realtimeLogs,
        sourceDate: Date(timeIntervalSince1970: 2_100),
        primaryUsed: 7,
        secondaryUsed: 9
    )

    let preferred = QuotaRefreshPolicy.preferredResult(
        fetchedResult: freshLogs,
        mode: .automatic,
        lastSuccessfulAPIResult: recentAPI
    )

    expect(preferred.source == .realtimeLogs, "automatic refresh accepts logs after they catch up")
    expect(preferred.snapshot.rateLimits.primary?.remainingPercent == 93, "fresh logs replace API snapshot when newer")
}

func testManualRefreshDoesNotForceCachedAPIOverFetchedLogs() {
    let recentAPI = makeResult(
        source: .api,
        sourceDate: Date(timeIntervalSince1970: 2_000),
        primaryUsed: 5,
        secondaryUsed: 8
    )
    let fallbackLogs = makeResult(
        source: .realtimeLogs,
        sourceDate: Date(timeIntervalSince1970: 1_900),
        primaryUsed: 12,
        secondaryUsed: 10
    )

    let preferred = QuotaRefreshPolicy.preferredResult(
        fetchedResult: fallbackLogs,
        mode: .apiManual,
        lastSuccessfulAPIResult: recentAPI
    )

    expect(preferred.source == .realtimeLogs, "manual refresh uses fetched fallback result if API is unavailable")
}

@main
struct TestRunner {
    static func main() {
        testRealtimeLogRowParsingUsesSQLitePipeSeparator()
        testAutomaticRefreshPrefersRecentAPIOverOlderLogs()
        testAutomaticRefreshAllowsLogsAfterTheyCatchUp()
        testManualRefreshDoesNotForceCachedAPIOverFetchedLogs()
        print("All tests passed.")
    }
}
