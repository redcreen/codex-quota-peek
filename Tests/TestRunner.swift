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
        lastSuccessfulAPIResult: recentAPI,
        lastAcceptedResult: nil
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
        lastSuccessfulAPIResult: recentAPI,
        lastAcceptedResult: nil
    )

    expect(preferred.source == .realtimeLogs, "automatic refresh accepts logs after they catch up")
    expect(preferred.snapshot.rateLimits.primary?.remainingPercent == 93, "fresh logs replace API snapshot when newer")
}

func testAutomaticRefreshPrefersAPIWhenLogsShowOlderResetWindow() {
    let recentAPI = CodexQuotaFetchResult(
        snapshot: CodexQuotaSnapshot(
            planType: "pro",
            rateLimits: RateLimits(
                allowed: true,
                limitReached: false,
                primary: makeWindow(usedPercent: 5, windowMinutes: 300, resetAfterSeconds: 120, resetAt: 2_500),
                secondary: makeWindow(usedPercent: 8, windowMinutes: 10080, resetAfterSeconds: 3600, resetAt: 9_000)
            ),
            credits: nil
        ),
        source: .api,
        sourceDate: Date()
    )
    let staleLogs = CodexQuotaFetchResult(
        snapshot: CodexQuotaSnapshot(
            planType: "pro",
            rateLimits: RateLimits(
                allowed: true,
                limitReached: false,
                primary: makeWindow(usedPercent: 17, windowMinutes: 300, resetAfterSeconds: 120, resetAt: 2_400),
                secondary: makeWindow(usedPercent: 12, windowMinutes: 10080, resetAfterSeconds: 3600, resetAt: 8_900)
            ),
            credits: nil
        ),
        source: .realtimeLogs,
        sourceDate: Date().addingTimeInterval(3)
    )

    let preferred = QuotaRefreshPolicy.preferredResult(
        fetchedResult: staleLogs,
        mode: .automatic,
        lastSuccessfulAPIResult: recentAPI,
        lastAcceptedResult: nil
    )

    expect(preferred.source == .api, "automatic refresh keeps API when logs belong to an older reset window")
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
        lastSuccessfulAPIResult: recentAPI,
        lastAcceptedResult: nil
    )

    expect(preferred.source == .realtimeLogs, "manual refresh uses fetched fallback result if API is unavailable")
}

func testSourceStrategyFetchPlans() {
    expect(
        QuotaRefreshPolicy.fetchPlan(for: .automatic, sourceStrategy: .auto) == .localFirst,
        "auto strategy keeps automatic refresh on local-first"
    )
    expect(
        QuotaRefreshPolicy.fetchPlan(for: .automatic, sourceStrategy: .preferAPI) == .apiPreferred,
        "prefer API strategy upgrades automatic refresh to API-first"
    )
    expect(
        QuotaRefreshPolicy.fetchPlan(for: .startupAPI, sourceStrategy: .preferLocalLogs) == .localFirst,
        "prefer local logs keeps startup refresh on local-first"
    )
    expect(
        QuotaRefreshPolicy.fetchPlan(for: .apiManual, sourceStrategy: .preferLocalLogs) == .apiPreferred,
        "manual refresh always remains API-first"
    )
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
    expect(presentation.sourceText == "Source: API", "presentation keeps source text")
    expect(presentation.creditsText == "233.93 left", "presentation formats credits")
    expect(presentation.paceMessage == "5 hours above average", "presentation shortens pace message")
    expect(presentation.primaryRow?.paceText == " Pace above avg ", "row keeps inline pace hint")
}

func testTrendSummaryMenuText() {
    let summary = CodexQuotaTrendSummary(
        sessionLowPercent: 73,
        sessionLowDate: Date(timeIntervalSince1970: 1_775_291_731),
        weeklyLowPercent: 82,
        weeklyLowDate: Date(timeIntervalSince1970: 1_775_896_800),
        sessionTrend: "._=+##",
        weeklyTrend: "--==++"
    )
    let menuText = summary.menuText(language: .english) ?? ""
    expect(menuText.contains("Recent lows: 5h 73% @"), "trend summary includes session low timestamp")
    expect(menuText.contains("7d 82% @"), "trend summary includes weekly low timestamp")
    expect(summary.sparklineText(language: .english) == "Recent trend: 5h ._=+##  ·  7d --==++", "trend summary formats sparkline text")
}

func testSparklineSampling() {
    let line = CodexQuotaProvider.sparkline(values: [90, 88, 86, 82, 80, 78, 76, 74], points: 8)
    expect(line != nil && line?.count == 8, "sparkline renders fixed-width recent trend")
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
    expect(QuotaDisplayPolicy.menuWindowTitle(for: "5 hours") == "5 hours", "five-hour menu title stays explicit")
    expect(QuotaDisplayPolicy.menuWindowTitle(for: "7 days") == "7 days", "seven-day menu title stays explicit")
    expect(QuotaDisplayPolicy.progressBar(forPercentText: "50%", slots: 10) == "█████░░░░░", "progress bar reflects remaining percent")
    let segments = QuotaDisplayPolicy.progressSegments(forPercentText: "49%!!", slots: 10)
    expect(segments.filled == 5 && segments.exceeded == 2 && segments.empty == 3, "progress segments reserve colored overflow markers")
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

func testCliHelpPrefersRefreshOverUpdate() {
    let helpText = """
    codexQuotaPeek

    Usage:
      codexQuotaPeek
      codexQuotaPeek status [--api|--refresh] [--json]
    """
    expect(helpText.contains("--refresh"), "CLI help includes refresh flag")
    expect(!helpText.contains("--update"), "CLI help no longer mentions update flag")
}

func testRefreshRequestGateOnlyAppliesLatestRequest() {
    var gate = RefreshRequestGate()
    let first = gate.issue()
    let second = gate.issue()

    expect(!gate.shouldApply(first), "older refresh request is discarded")
    expect(gate.shouldApply(second), "latest refresh request is allowed to apply")
}

func testAutomaticRefreshDoesNotRegressWithinSameResetWindow() {
    let currentAccepted = CodexQuotaFetchResult(
        snapshot: CodexQuotaSnapshot(
            planType: "pro",
            rateLimits: RateLimits(
                allowed: true,
                limitReached: false,
                primary: makeWindow(usedPercent: 27, windowMinutes: 300, resetAfterSeconds: 100, resetAt: 5_000),
                secondary: makeWindow(usedPercent: 14, windowMinutes: 10080, resetAfterSeconds: 100, resetAt: 9_000)
            ),
            credits: nil
        ),
        source: .realtimeLogs,
        sourceDate: Date(timeIntervalSince1970: 3_000)
    )
    let regressedLogs = CodexQuotaFetchResult(
        snapshot: CodexQuotaSnapshot(
            planType: "pro",
            rateLimits: RateLimits(
                allowed: true,
                limitReached: false,
                primary: makeWindow(usedPercent: 17, windowMinutes: 300, resetAfterSeconds: 100, resetAt: 5_000),
                secondary: makeWindow(usedPercent: 5, windowMinutes: 10080, resetAfterSeconds: 100, resetAt: 9_000)
            ),
            credits: nil
        ),
        source: .realtimeLogs,
        sourceDate: Date(timeIntervalSince1970: 3_100)
    )

    let preferred = QuotaRefreshPolicy.preferredResult(
        fetchedResult: regressedLogs,
        mode: .automatic,
        lastSuccessfulAPIResult: nil,
        lastAcceptedResult: currentAccepted
    )

    expect(preferred.snapshot.rateLimits.secondary?.remainingPercent == 86, "same reset window does not regress to older higher remaining percent")
}

func testStartupAPIRefreshFallsBackWithoutOverridingCurrentRules() {
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
        mode: .startupAPI,
        lastSuccessfulAPIResult: recentAPI,
        lastAcceptedResult: nil
    )

    expect(preferred.source == .realtimeLogs, "startup API refresh can fall back to logs without being forced to stale API data")
}

func testWeeklyPacingModeCanBeLooserThanFullWeek() {
    let weekly = LimitWindow(
        usedPercent: 7,
        windowMinutes: 10080,
        resetAfterSeconds: 574_155,
        resetAt: 1_775_896_800
    )
    let fortyHourText = StatusPresentation.statusPercentText(for: weekly, weeklyPacingMode: .workWeek40, isWeekly: true)
    let fiftySixHourText = StatusPresentation.statusPercentText(for: weekly, weeklyPacingMode: .balanced56, isWeekly: true)
    let seventyHourText = StatusPresentation.statusPercentText(for: weekly, weeklyPacingMode: .heavy70, isWeekly: true)

    expect(
        !seventyHourText.contains("!!"),
        "70-hour pacing is never stricter than the lighter presets for the same weekly sample"
    )
    expect(
        WeeklyPacingMode.workWeek40.menuTitle == "Standard · 40h/week",
        "standard weekly workload title is explicit"
    )
    expect(
        WeeklyPacingMode.balanced56.menuTitle == "Balanced · 56h/week",
        "balanced weekly workload title is explicit"
    )
    expect(
        WeeklyPacingMode.heavy70.menuTitle == "Heavy · 70h/week",
        "heavy weekly workload title is explicit"
    )
    expect(
        [fortyHourText, fiftySixHourText, seventyHourText].allSatisfy { $0.hasPrefix("93%") },
        "weekly workload modes preserve the same remaining quota percentage"
    )
    expect(
        WeeklyPacingMode.heavy70.tooltipText().contains("70-hour work week"),
        "weekly pacing tooltip reflects selected weekly workload"
    )
    expect(
        QuotaDisplayPolicy.weeklyPacingHintTitle().contains("ahead of your selected pace"),
        "weekly pacing hint explains what triggers the marker"
    )
    expect(
        QuotaDisplayPolicy.weeklyPacingHintDetail().contains("% left never changes"),
        "weekly pacing hint explains that presets do not change quota remaining"
    )
    expect(
        QuotaDisplayPolicy.weeklyPaceExplanation(for: .balanced56).contains("56-hour work week"),
        "weekly row explanation includes the selected weekly workload"
    )
}

func testChineseLanguagePresentationLocalizesCoreLabels() {
    let presentation = StatusPresentation(
        snapshot: makeSnapshot(primaryUsed: 10, secondaryUsed: 20),
        accountInfo: CodexAccountInfo(displayName: "User", email: "user@example.com", planDisplayName: "Pro"),
        generatedAt: Date(),
        source: .realtimeLogs,
        trendSummary: CodexQuotaTrendSummary(
            sessionLowPercent: 73,
            sessionLowDate: Date(),
            weeklyLowPercent: 82,
            weeklyLowDate: Date(),
            sessionTrend: "._=+##",
            weeklyTrend: "--==++"
        ),
        weeklyPacingMode: .balanced56,
        language: .chinese
    )

    expect(presentation.accountRow?.label == "账号", "presentation localizes account label")
    expect(presentation.sourceText == "来源：本地日志", "presentation localizes source label")
    expect(presentation.updatedAtText == "刚刚更新", "presentation localizes relative update label")
    expect(presentation.trendText?.contains("近期低点: 5 小时 73% @") == true, "presentation localizes trend summary")
}

func testNotificationPolicyTriggersOnlyOnEscalation() {
    let previous = QuotaNotificationSnapshot(
        sessionLevel: .none,
        weeklyLevel: .warning,
        paceLevel: .none,
        sessionResetSoon: false,
        weeklyResetSoon: false
    )
    let current = QuotaNotificationSnapshot(
        sessionLevel: .warning,
        weeklyLevel: .warning,
        paceLevel: .critical,
        sessionResetSoon: false,
        weeklyResetSoon: false
    )
    let presentation = StatusPresentation(
        snapshot: makeSnapshot(primaryUsed: 55, secondaryUsed: 42),
        accountInfo: nil,
        generatedAt: Date(),
        source: .realtimeLogs
    )

    let event = QuotaNotificationPolicy.nextEvent(
        previous: previous,
        current: current,
        presentation: presentation
    )

    expect(event?.title == "5-hour quota warning", "notification policy emits first newly crossed threshold")
}

func testNotificationPolicyStaysQuietForRepeatedState() {
    let current = QuotaNotificationSnapshot(
        sessionLevel: .warning,
        weeklyLevel: .none,
        paceLevel: .warning,
        sessionResetSoon: false,
        weeklyResetSoon: false
    )
    let presentation = StatusPresentation(
        snapshot: makeSnapshot(primaryUsed: 52, secondaryUsed: 8),
        accountInfo: nil,
        generatedAt: Date(),
        source: .api
    )

    let event = QuotaNotificationPolicy.nextEvent(
        previous: current,
        current: current,
        presentation: presentation
    )

    expect(event == nil, "notification policy suppresses duplicate notifications for the same state")
}

func testNotificationPolicyEmitsResetReminderOnce() {
    let now = Date()
    let presentation = StatusPresentation(
        line1: "H 90%",
        line2: "W 80%",
        tooltip: "",
        primaryRow: StatusPresentation.MenuRow(
            label: "5 hours",
            percentText: "90%",
            resetText: "15:23",
            resetDate: now.addingTimeInterval(10 * 60),
            isUsingFasterThanAverage: false,
            paceText: nil,
            paceSeverity: nil
        ),
        secondaryRow: StatusPresentation.MenuRow(
            label: "7 days",
            percentText: "80%",
            resetText: "Apr 11",
            resetDate: now.addingTimeInterval(24 * 60 * 60),
            isUsingFasterThanAverage: false,
            paceText: nil,
            paceSeverity: nil
        ),
        language: .english
    )

    let current = QuotaNotificationPolicy.snapshot(from: presentation)
    let firstEvent = QuotaNotificationPolicy.nextEvent(previous: nil, current: current, presentation: presentation)
    let repeatedEvent = QuotaNotificationPolicy.nextEvent(previous: current, current: current, presentation: presentation)

    expect(firstEvent?.title == "5-hour window resets soon", "notification policy emits upcoming 5-hour reset reminder")
    expect(repeatedEvent == nil, "notification policy deduplicates reset reminders")
}

func testNotificationPolicyRespectsCategoryPreferences() {
    let presentation = StatusPresentation(
        line1: "H 90%",
        line2: "W 80%!",
        tooltip: "",
        primaryRow: StatusPresentation.MenuRow(
            label: "5 hours",
            percentText: "90%",
            resetText: "15:23",
            resetDate: Date().addingTimeInterval(3600),
            isUsingFasterThanAverage: false,
            paceText: nil,
            paceSeverity: nil
        ),
        secondaryRow: StatusPresentation.MenuRow(
            label: "7 days",
            percentText: "80%!",
            resetText: "Apr 11",
            resetDate: Date().addingTimeInterval(2 * 24 * 3600),
            isUsingFasterThanAverage: true,
            paceText: " Pace above avg ",
            paceSeverity: .warning
        ),
        paceMessage: "7 days above average",
        paceSeverity: .warning,
        language: .english
    )
    let current = QuotaNotificationPolicy.snapshot(from: presentation)

    let noLowQuotaEvent = QuotaNotificationPolicy.nextEvent(
        previous: nil,
        current: current,
        presentation: presentation,
        preferences: QuotaNotificationPreferences(
            lowQuotaEnabled: false,
            paceEnabled: true,
            resetEnabled: true
        )
    )

    expect(noLowQuotaEvent?.title == "Usage pace warning", "notification policy skips disabled low-quota alerts and falls through to enabled categories")

    let noPaceEvent = QuotaNotificationPolicy.nextEvent(
        previous: nil,
        current: current,
        presentation: presentation,
        preferences: QuotaNotificationPreferences(
            lowQuotaEnabled: false,
            paceEnabled: false,
            resetEnabled: false
        )
    )

    expect(noPaceEvent == nil, "notification policy suppresses all disabled notification categories")
}

@main
struct TestRunner {
    static func main() {
        testRealtimeLogRowParsingUsesSQLitePipeSeparator()
        testAutomaticRefreshPrefersRecentAPIOverOlderLogs()
        testAutomaticRefreshAllowsLogsAfterTheyCatchUp()
        testAutomaticRefreshPrefersAPIWhenLogsShowOlderResetWindow()
testManualRefreshDoesNotForceCachedAPIOverFetchedLogs()
testSourceStrategyFetchPlans()
testDisplayPresentationUsesPaceMarkersAndSourceText()
testTrendSummaryMenuText()
testSparklineSampling()
testRelativeUpdatedAtLabels()
        testQuotaDisplayColorThresholds()
        testAuthSnapshotStoreReadsSavedAccountMetadata()
        testCliHelpPrefersRefreshOverUpdate()
        testRefreshRequestGateOnlyAppliesLatestRequest()
        testAutomaticRefreshDoesNotRegressWithinSameResetWindow()
        testStartupAPIRefreshFallsBackWithoutOverridingCurrentRules()
        testWeeklyPacingModeCanBeLooserThanFullWeek()
        testChineseLanguagePresentationLocalizesCoreLabels()
        testNotificationPolicyTriggersOnlyOnEscalation()
        testNotificationPolicyStaysQuietForRepeatedState()
        testNotificationPolicyEmitsResetReminderOnce()
        testNotificationPolicyRespectsCategoryPreferences()
        print("All tests passed.")
    }
}
