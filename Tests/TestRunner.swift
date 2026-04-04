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
        ),
        credits: nil
    )
}

func makeResult(source: CodexQuotaFetchSource, sourceDate: Date?, primaryUsed: Double, secondaryUsed: Double) -> CodexQuotaFetchResult {
    CodexQuotaFetchResult(
        snapshot: makeSnapshot(primaryUsed: primaryUsed, secondaryUsed: secondaryUsed),
        source: source,
        sourceDate: sourceDate
    )
}

func makeJWT(_ payload: [String: Any]) -> String {
    let headerData = try! JSONSerialization.data(withJSONObject: ["alg": "none", "typ": "JWT"])
    let payloadData = try! JSONSerialization.data(withJSONObject: payload)

    func encode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    return "\(encode(headerData)).\(encode(payloadData)).sig"
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

func testDisplayPresentationUsesPaceMarkersAndSourceText() {
    let primary = LimitWindow(
        usedPercent: 65,
        windowMinutes: 300,
        resetAfterSeconds: 14_400,
        resetAt: 1_775_292_000
    )
    let secondary = LimitWindow(
        usedPercent: 10,
        windowMinutes: 10080,
        resetAfterSeconds: 500_000,
        resetAt: 1_775_896_800
    )
    let snapshot = CodexQuotaSnapshot(
        planType: "pro",
        rateLimits: RateLimits(allowed: true, limitReached: false, primary: primary, secondary: secondary),
        credits: CreditsInfo(hasCredits: true, unlimited: false, balance: "233.93")
    )
    let presentation = StatusPresentation(
        snapshot: snapshot,
        accountInfo: CodexAccountInfo(displayName: "redcreen qq", email: "67560691@qq.com", planDisplayName: "Pro"),
        generatedAt: Date(),
        source: .api
    )

    expect(presentation.line1 == "H 35%!!", "status line shows critical pace marker")
    expect(presentation.line2 == "W 90%", "status line omits markers when pace is normal")
    expect(presentation.sourceText == "Current value from API", "presentation keeps source text")
    expect(presentation.creditsText == "233.93 left", "presentation formats credits")
}

func testRelativeUpdatedAtLabels() {
    let now = Date(timeIntervalSince1970: 2_000)
    expect(StatusPresentation.relativeUpdatedAtLabel(for: Date(timeIntervalSince1970: 1_997), now: now) == "just updated", "fresh timestamps show just updated")
    expect(StatusPresentation.relativeUpdatedAtLabel(for: Date(timeIntervalSince1970: 1_950), now: now) == "50s", "sub-minute timestamps show seconds")
    expect(StatusPresentation.relativeUpdatedAtLabel(for: Date(timeIntervalSince1970: 1_880), now: now) == "2m", "older timestamps show minutes")
}

func testQuotaDisplayColorThresholds() {
    expect(QuotaDisplayPolicy.colorLevel(forPercentText: "82%") == .normal, "high remaining percent is green tier")
    expect(QuotaDisplayPolicy.colorLevel(forPercentText: "49%!") == .warning, "below fifty percent is yellow tier")
    expect(QuotaDisplayPolicy.colorLevel(forPercentText: "29%!!") == .critical, "below thirty percent is red tier")
    let split = QuotaDisplayPolicy.splitPercentComponents("95%!!")
    expect(split.0 == "95%" && split.1 == "!!", "percent text splits into value and pace marker")
    expect(QuotaDisplayPolicy.menuWindowTitle(for: "5 hours") == "Session", "session menu title is user friendly")
    expect(QuotaDisplayPolicy.menuWindowTitle(for: "1 week") == "Weekly", "weekly menu title is user friendly")
    expect(QuotaDisplayPolicy.progressBar(forPercentText: "50%", slots: 10) == "█████░░░░░", "progress bar reflects remaining percent")
}

func testAuthSnapshotStoreReadsSavedAccountMetadata() {
    let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("codex-quota-peek-tests-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let codexDir = tempRoot.appendingPathComponent(".codex")
    try! FileManager.default.createDirectory(at: codexDir, withIntermediateDirectories: true)

    let idToken = makeJWT([
        "name": "Second User",
        "email": "second@example.com",
        "https://api.openai.com/auth": [
            "chatgpt_plan_type": "plus"
        ]
    ])
    let authJSON = """
    {
      "tokens": {
        "id_token": "\(idToken)",
        "access_token": "\(idToken)",
        "account_id": "acct-second"
      }
    }
    """
    try! authJSON.data(using: .utf8)!.write(to: codexDir.appendingPathComponent("auth.json"))

    let store = CodexAuthSnapshotStore(homeDirectory: tempRoot)
    let saved = store.saveCurrentAuthSnapshot()
    expect(saved?.displayName == "Second User", "snapshot store saves display name from auth")
    expect(saved?.planDisplayName == "Plus", "snapshot store humanizes plan name")

    let accounts = store.loadStoredAccounts()
    expect(accounts.count == 1, "snapshot store loads saved accounts")
    expect(accounts.first?.snapshotIdentifier == "acct-second", "snapshot store uses account id as snapshot identifier")
}

@main
struct TestRunner {
    static func main() {
        testRealtimeLogRowParsingUsesSQLitePipeSeparator()
        testAutomaticRefreshPrefersRecentAPIOverOlderLogs()
        testAutomaticRefreshAllowsLogsAfterTheyCatchUp()
        testManualRefreshDoesNotForceCachedAPIOverFetchedLogs()
        testDisplayPresentationUsesPaceMarkersAndSourceText()
        testRelativeUpdatedAtLabels()
        testQuotaDisplayColorThresholds()
        testAuthSnapshotStoreReadsSavedAccountMetadata()
        print("All tests passed.")
    }
}
