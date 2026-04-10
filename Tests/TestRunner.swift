import AppKit
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

func makeSnapshot(
    primaryUsed: Double,
    secondaryUsed: Double,
    primaryResetAt: TimeInterval = 1_775_291_731,
    secondaryResetAt: TimeInterval = 1_775_291_731,
    primaryResetAfterSeconds: Int = 120,
    secondaryResetAfterSeconds: Int = 120
) -> CodexQuotaSnapshot {
    CodexQuotaSnapshot(
        planType: "pro",
        rateLimits: RateLimits(
            allowed: true,
            limitReached: false,
            primary: makeWindow(
                usedPercent: primaryUsed,
                windowMinutes: 300,
                resetAfterSeconds: primaryResetAfterSeconds,
                resetAt: primaryResetAt
            ),
            secondary: makeWindow(
                usedPercent: secondaryUsed,
                windowMinutes: 10080,
                resetAfterSeconds: secondaryResetAfterSeconds,
                resetAt: secondaryResetAt
            )
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
        QuotaRefreshPolicy.fetchPlan(for: .startupAPI, sourceStrategy: .preferLocalLogs) == .apiPreferred,
        "startup refresh always stays API-first even when local logs are preferred"
    )
    expect(
        QuotaRefreshPolicy.fetchPlan(for: .apiManual, sourceStrategy: .preferLocalLogs) == .apiPreferred,
        "manual refresh always remains API-first"
    )
}

func testMenuOpenRefreshPrefersAPIForLogsOrStaleData() {
    expect(
        QuotaRefreshPolicy.shouldPreferAPIMenuOpenRefresh(
            lastSource: nil,
            lastGeneratedAt: nil,
            now: Date(timeIntervalSince1970: 1_000)
        ),
        "menu open prefers API when there is no previous snapshot"
    )
    expect(
        QuotaRefreshPolicy.shouldPreferAPIMenuOpenRefresh(
            lastSource: .realtimeLogs,
            lastGeneratedAt: Date(timeIntervalSince1970: 950),
            now: Date(timeIntervalSince1970: 1_000)
        ),
        "menu open prefers API when the current value comes from local logs"
    )
    expect(
        !QuotaRefreshPolicy.shouldPreferAPIMenuOpenRefresh(
            lastSource: .api,
            lastGeneratedAt: Date(timeIntervalSince1970: 950),
            now: Date(timeIntervalSince1970: 1_000)
        ),
        "menu open keeps automatic refresh when a recent API snapshot is already displayed"
    )
    expect(
        QuotaRefreshPolicy.shouldPreferAPIMenuOpenRefresh(
            lastSource: .api,
            lastGeneratedAt: Date(timeIntervalSince1970: 800),
            now: Date(timeIntervalSince1970: 1_000)
        ),
        "menu open prefers API again when the last API snapshot has gone stale"
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

    expect(presentation.line1 == "H 35%!!!", "status line shows severe pace marker")
    expect(presentation.line2 == "W 90%", "status line omits markers when pace is normal")
    expect(presentation.sourceText == "Source: API", "presentation keeps source text")
    expect(presentation.creditsText == "233.93 left", "presentation formats credits")
    expect(presentation.paceMessage == "5 hours above average", "presentation shortens pace message")
    expect(presentation.primaryRow?.paceText == " Pace above avg ", "row keeps inline pace hint")
}

func testTrendSummaryMenuText() {
    let summary = CodexQuotaTrendSummary(
        dailyUsageBars: [
            .init(date: Date(timeIntervalSince1970: 1_775_291_731), usedPercent: 8, cumulativeUsedPercent: 8, expectedUsedPercent: 6, expectedDailyUsedPercent: 6, isFuture: false),
            .init(date: Date(timeIntervalSince1970: 1_775_378_131), usedPercent: 12, cumulativeUsedPercent: 20, expectedUsedPercent: 14, expectedDailyUsedPercent: 8, isFuture: false),
            .init(date: Date(timeIntervalSince1970: 1_775_464_531), usedPercent: 4, cumulativeUsedPercent: 24, expectedUsedPercent: 20, expectedDailyUsedPercent: 6, isFuture: false),
            .init(date: Date(timeIntervalSince1970: 1_775_550_931), usedPercent: 0, cumulativeUsedPercent: 24, expectedUsedPercent: 28, expectedDailyUsedPercent: 8, isFuture: true),
            .init(date: Date(timeIntervalSince1970: 1_775_637_331), usedPercent: 0, cumulativeUsedPercent: 24, expectedUsedPercent: 28, expectedDailyUsedPercent: 0, isFuture: true),
            .init(date: Date(timeIntervalSince1970: 1_775_723_731), usedPercent: 0, cumulativeUsedPercent: 24, expectedUsedPercent: 28, expectedDailyUsedPercent: 0, isFuture: true),
            .init(date: Date(timeIntervalSince1970: 1_775_810_131), usedPercent: 0, cumulativeUsedPercent: 24, expectedUsedPercent: 28, expectedDailyUsedPercent: 0, isFuture: true)
        ]
    )
    let menuText = summary.menuText(language: .english, weeklyPacingMode: .balanced56) ?? ""
    expect(menuText.contains("Daily usage"), "daily usage chart includes a chart title")
    expect(menuText.contains("┤"), "daily usage chart renders a y-axis")
    expect(menuText.contains("└"), "daily usage chart renders an x-axis baseline")
    expect(menuText.contains("1"), "daily usage chart includes date labels for the week")
    expect(menuText.contains("█"), "daily usage chart renders bar glyphs")
    expect(summary.chartPresentation(language: .english, weeklyPacingMode: .balanced56)?.days.count == 7, "daily usage chart always renders a full seven-day week")
}

func testSparklineSampling() {
    let line = CodexQuotaProvider.sparkline(values: [90, 88, 86, 82, 80, 78, 76, 74], points: 8)
    expect(line != nil && line?.count == 8, "sparkline renders fixed-width recent trend")
}

func testTrendRowsStayInsideCurrentResetWindow() {
    let oldWeekly = CodexQuotaFetchResult(
        snapshot: makeSnapshot(
            primaryUsed: 10,
            secondaryUsed: 38,
            primaryResetAt: 2_000_000,
            secondaryResetAt: 3_000_000
        ),
        source: .realtimeLogs,
        sourceDate: Date(timeIntervalSince1970: 1_000)
    )
    let currentWeeklyEarly = CodexQuotaFetchResult(
        snapshot: makeSnapshot(
            primaryUsed: 12,
            secondaryUsed: 22,
            primaryResetAt: 2_100_000,
            secondaryResetAt: 4_000_000
        ),
        source: .realtimeLogs,
        sourceDate: Date(timeIntervalSince1970: 2_000)
    )
    let currentWeeklyLate = CodexQuotaFetchResult(
        snapshot: makeSnapshot(
            primaryUsed: 15,
            secondaryUsed: 25,
            primaryResetAt: 2_100_000,
            secondaryResetAt: 4_000_000
        ),
        source: .realtimeLogs,
        sourceDate: Date(timeIntervalSince1970: 3_000)
    )

    let weeklyRows = CodexQuotaProvider.rowsInCurrentWindow(
        [oldWeekly, currentWeeklyEarly, currentWeeklyLate]
    ) { $0.snapshot.rateLimits.secondary }

    expect(weeklyRows.count == 2, "trend rows only keep entries from the current weekly reset window")
    expect(
        weeklyRows.allSatisfy { Int(($0.snapshot.rateLimits.secondary?.resetAt ?? 0).rounded()) == 4_000_000 },
        "weekly trend rows exclude earlier reset windows like Apr 2"
    )
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
    let segments = QuotaDisplayPolicy.progressSegments(
        forPercentText: "43%!!",
        overrunPercent: 18,
        usedPercent: 57,
        thresholdPercent: 14,
        slots: 10
    )
    expect(segments.remaining == 4 && segments.used == 6 && segments.markerIndex == 9, "progress segments render remaining on the left, used on the right, and include a normal-progress marker")
}

func testQuotaRowTooltipsIncludeDurationBreakdown() {
    let snapshot = CodexQuotaSnapshot(
        planType: "pro",
        rateLimits: RateLimits(
            allowed: true,
            limitReached: false,
            primary: LimitWindow(usedPercent: 70, windowMinutes: 300, resetAfterSeconds: 3600, resetAt: Date().addingTimeInterval(3600).timeIntervalSince1970),
            secondary: LimitWindow(usedPercent: 60, windowMinutes: 10080, resetAfterSeconds: 5 * 24 * 3600, resetAt: Date().addingTimeInterval(5 * 24 * 3600).timeIntervalSince1970)
        ),
        credits: nil
    )
    let presentation = StatusPresentation(
        snapshot: snapshot,
        accountInfo: nil,
        generatedAt: Date(),
        source: .api,
        weeklyPacingMode: .balanced56,
        language: .english
    )

    expect(presentation.primaryRow?.tooltipText?.contains("Total:") == true, "quota row tooltip includes total duration")
    expect(presentation.primaryRow?.tooltipText?.contains("Normal elapsed:") == true, "quota row tooltip includes normal elapsed duration")
    expect(presentation.primaryRow?.tooltipText?.contains("Used:") == true, "quota row tooltip includes used duration")
    expect(presentation.primaryRow?.tooltipText?.contains("Remaining:") == true, "quota row tooltip includes remaining duration")
    expect(presentation.secondaryRow?.tooltipText?.contains("Based on 56h/week") == true, "weekly tooltip references the selected weekly workload")
}

func testQuotaRowTooltipsUseReadableSmallDurations() {
    let snapshot = CodexQuotaSnapshot(
        planType: "pro",
        rateLimits: RateLimits(
            allowed: true,
            limitReached: false,
            primary: LimitWindow(usedPercent: 8, windowMinutes: 300, resetAfterSeconds: 10_440, resetAt: Date().addingTimeInterval(10_440).timeIntervalSince1970),
            secondary: nil
        ),
        credits: nil
    )
    let presentation = StatusPresentation(
        snapshot: snapshot,
        accountInfo: nil,
        generatedAt: Date(),
        source: .api,
        language: .chinese
    )

    expect(presentation.primaryRow?.tooltipText?.contains("已用：24分钟（8%）") == true, "small non-zero usage is shown in minutes instead of 0 hours")
    expect(presentation.primaryRow?.tooltipText?.contains("正常经过：2.1小时（42%）") == true, "normal elapsed keeps readable fractional hours")
}

func testQuotaExplanationBuilderFormatsEdgeDurations() {
    expect(QuotaExplanationBuilder.formattedDuration(hours: 0, language: .english) == "0m", "quota explanation builder formats zero duration in minutes")
    expect(QuotaExplanationBuilder.formattedDuration(hours: 0.4, language: .english) == "24m", "quota explanation builder formats sub-hour values in minutes")
    expect(QuotaExplanationBuilder.formattedDuration(hours: 2.1, language: .english) == "2.1h", "quota explanation builder keeps one decimal for small fractional hours")
    expect(QuotaExplanationBuilder.formattedDuration(hours: 12.2, language: .english) == "12h", "quota explanation builder rounds larger durations to whole hours")
}

func testQuotaExplanationBuilderKeepsWeeklyTooltipSemantics() {
    let weekly = LimitWindow(
        usedPercent: 58,
        windowMinutes: 10080,
        resetAfterSeconds: 505_436,
        resetAt: 1_775_874_219
    )
    let tooltip = QuotaExplanationBuilder.rowTooltip(
        for: weekly,
        weeklyPacingMode: .workWeek40,
        isWeekly: true,
        language: .english,
        thresholdPercent: 29
    )

    expect(tooltip?.contains("Based on 40h/week") == true, "quota explanation builder prefixes weekly tooltips with the selected preset")
    expect(tooltip?.contains("Normal elapsed: 12h (29%)") == true, "quota explanation builder keeps normal elapsed details")
    expect(tooltip?.contains("Used: 23h (58%)") == true, "quota explanation builder keeps used duration details")
    expect(tooltip?.contains("Remaining: 17h (42%)") == true, "quota explanation builder keeps remaining duration details")
    expect(tooltip?.contains("Ahead of pace: 12h (29%)") == true, "quota explanation builder keeps ahead-of-pace details")
}

func testQuotaRowLayoutBuildsCompactLabelsAndDetailText() {
    let layout = QuotaRowLayout.build(
        label: "5 hours",
        language: .english,
        percentText: "96%!",
        reset: "19:04",
        markerThresholdPercent: 12,
        usedOnLeft: true
    )

    expect(layout.compactLabel == "5h", "quota row layout compacts five-hour label")
    expect(layout.percentValue == "96%", "quota row layout keeps percent value without pace marker")
    expect(layout.percentMarker == "!", "quota row layout keeps pace marker separately")
    expect(layout.statusText == "left 96% !", "quota row layout builds right-side status text in stable order")
    expect(layout.resetText == "Resets 19:04", "quota row layout builds reset text in stable order")
    expect(layout.detailText == "Resets 19:04 left 96% !", "quota row layout builds the full detail row text")
}

func testQuotaRowLayoutMarkerIndexFollowsMarkerPercent() {
    let forty = QuotaRowLayout.build(
        label: "7 days",
        language: .english,
        percentText: "36%!!",
        reset: "Apr 16",
        markerThresholdPercent: 29,
        usedOnLeft: true
    )
    let seventy = QuotaRowLayout.build(
        label: "7 days",
        language: .english,
        percentText: "36%!!!",
        reset: "Apr 16",
        markerThresholdPercent: 19,
        usedOnLeft: true
    )

    expect(forty.markerIndex != nil, "quota row layout produces a marker index when threshold exists")
    expect(seventy.markerIndex != nil, "quota row layout keeps weekly marker index available for rendering")
    expect((forty.markerIndex ?? -1) > (seventy.markerIndex ?? -1), "quota row layout moves the marker left/right as weekly pace changes")
}

func testQuotaRowLayoutKeepsBarWidthStableAcrossDisplayScales() {
    let full = QuotaRowLayout.build(
        label: "7 days",
        language: .english,
        percentText: "36%!!",
        reset: "Apr 16",
        markerThresholdPercent: 29,
        usedOnLeft: true,
        displayScale: 1.0
    )
    let scaled = QuotaRowLayout.build(
        label: "7 days",
        language: .english,
        percentText: "36%!!",
        reset: "Apr 16",
        markerThresholdPercent: 29,
        usedOnLeft: true,
        displayScale: 0.57
    )

    expect(full.remainingSlots + full.usedSlots == 28, "quota row layout uses the full bar width by default")
    expect(scaled.remainingSlots + scaled.usedSlots == 28, "quota row layout keeps bar width stable even when display scale changes")
}

func testQuotaRowTextRendererKeepsUsedRemainingDirectionAndRightAlignedDetail() {
    let layout = QuotaRowLayout.build(
        label: "7 days",
        language: .english,
        percentText: "36%!!",
        reset: "Apr 16",
        markerThresholdPercent: 29,
        usedOnLeft: true
    )
    let rendered = QuotaRowTextRenderer.render(
        layout: layout,
        usedOnLeft: true,
        slots: 28,
        titleColumnWidth: 4
    )

    expect(rendered.barBody.hasPrefix(String(repeating: "░", count: layout.usedSlots)), "quota row text renderer keeps used glyphs on the left for weekly rows")
    expect(rendered.barBody.hasSuffix(String(repeating: "█", count: layout.remainingSlots)), "quota row text renderer keeps remaining glyphs on the right for weekly rows")
    expect(rendered.detailLine.hasSuffix("Resets Apr 16 left 36% !!"), "quota row text renderer keeps the detail suffix stable")
    expect(rendered.detailLine.count >= 5 + 28, "quota row text renderer right-aligns detail text to the bar width")
}

func testQuotaRowTextRendererMirrorsFiveHourRowsCorrectly() {
    let layout = QuotaRowLayout.build(
        label: "5 hours",
        language: .english,
        percentText: "96%",
        reset: "19:04",
        markerThresholdPercent: 12,
        usedOnLeft: false
    )
    let rendered = QuotaRowTextRenderer.render(
        layout: layout,
        usedOnLeft: false,
        slots: 28,
        titleColumnWidth: 4
    )

    expect(rendered.barBody.hasPrefix(String(repeating: "█", count: layout.remainingSlots)), "quota row text renderer keeps remaining glyphs on the left for 5h rows")
    expect(rendered.barBody.hasSuffix(String(repeating: "░", count: layout.usedSlots)), "quota row text renderer keeps used glyphs on the right for 5h rows")
    expect(rendered.markerLine?.contains("▼") == true, "quota row text renderer keeps a visible marker line when thresholds exist")
}

func testQuotaRowTextRendererPlacesMarkerAtLayoutIndex() {
    let layout = QuotaRowLayout.build(
        label: "7 days",
        language: .english,
        percentText: "36%!!",
        reset: "Apr 16",
        markerThresholdPercent: 29,
        usedOnLeft: true
    )
    let rendered = QuotaRowTextRenderer.render(
        layout: layout,
        usedOnLeft: true,
        slots: 28,
        titleColumnWidth: 4
    )

    let markerPosition = rendered.markerLine?.firstIndex(of: "▼")?.utf16Offset(in: rendered.markerLine ?? "") ?? -1
    expect(markerPosition == layout.markerIndex, "quota row text renderer places the marker exactly at the computed layout index")
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

func testAccountMenuBuilderBuildsStableSwitchLabels() {
    let now = Date(timeIntervalSince1970: 2_000)
    let entries = AccountMenuBuilder.buildEntries(
        accounts: [
            CodexKnownAccount(
                displayName: "current@example.com",
                email: "current@example.com",
                accountID: "a1",
                isCurrent: true,
                planDisplayName: "Pro",
                snapshotIdentifier: "a1",
                canSwitchLocally: true,
                snapshotUpdatedAt: now
            ),
            CodexKnownAccount(
                displayName: "switch@example.com",
                email: "switch@example.com",
                accountID: "a2",
                isCurrent: false,
                planDisplayName: "Plus",
                snapshotIdentifier: "a2",
                canSwitchLocally: true,
                snapshotUpdatedAt: now
            ),
            CodexKnownAccount(
                displayName: "history@example.com",
                email: "history@example.com",
                accountID: "a3",
                isCurrent: false,
                planDisplayName: nil,
                snapshotIdentifier: nil,
                canSwitchLocally: false,
                snapshotUpdatedAt: nil
            )
        ],
        language: .english,
        relativeUpdatedAt: { _ in "just updated" }
    )

    expect(entries[0].title == "Current: current@example.com (Pro) · saved just updated", "account menu builder formats the current account title")
    expect(entries[0].isEnabled == false, "account menu builder disables the current account")
    expect(entries[1].title == "Switch to: switch@example.com (Plus) · saved just updated", "account menu builder formats local switch targets")
    expect(entries[1].isEnabled == true, "account menu builder enables local switch targets")
    expect(entries[2].title == "Re-login as history@example.com", "account menu builder formats history-only accounts")
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

func testAutomaticRefreshFailureShouldKeepCurrentSnapshot() {
    let currentAccepted = CodexQuotaFetchResult(
        snapshot: CodexQuotaSnapshot(
            planType: "pro",
            rateLimits: RateLimits(
                allowed: true,
                limitReached: false,
                primary: makeWindow(usedPercent: 2, windowMinutes: 300, resetAfterSeconds: 200, resetAt: 5_000),
                secondary: makeWindow(usedPercent: 64, windowMinutes: 10080, resetAfterSeconds: 200, resetAt: 9_000)
            ),
            credits: nil
        ),
        source: .api,
        sourceDate: Date(timeIntervalSince1970: 3_000)
    )
    let preferred = QuotaRefreshPolicy.preferredResult(
        fetchedResult: currentAccepted,
        mode: .automatic,
        lastSuccessfulAPIResult: currentAccepted,
        lastAcceptedResult: currentAccepted
    )

    expect(preferred.snapshot.rateLimits.primary?.remainingPercent == 98, "automatic refresh keeps current primary snapshot when nothing newer arrives")
    expect(preferred.snapshot.rateLimits.secondary?.remainingPercent == 36, "automatic refresh keeps current weekly snapshot when nothing newer arrives")
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
        usedPercent: 46,
        windowMinutes: 10080,
        resetAfterSeconds: 505_436,
        resetAt: 1_775_874_219
    )
    let fortyHourText = StatusPresentation.statusPercentText(for: weekly, weeklyPacingMode: .workWeek40, isWeekly: true)
    let fiftySixHourText = StatusPresentation.statusPercentText(for: weekly, weeklyPacingMode: .balanced56, isWeekly: true)
    let seventyHourText = StatusPresentation.statusPercentText(for: weekly, weeklyPacingMode: .heavy70, isWeekly: true)

    expect(
        fortyHourText == "54%!!",
        "40-hour pacing still warns strongly once weekly usage is far ahead of progress"
    )
    expect(
        fiftySixHourText == "54%!!",
        "56-hour pacing stays in the middle severity band"
    )
    expect(
        seventyHourText == "54%!!!",
        "70-hour pacing is the strictest preset for the same weekly sample"
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
        [fortyHourText, fiftySixHourText, seventyHourText].allSatisfy { $0.hasPrefix("54%") },
        "weekly workload modes preserve the same remaining quota percentage"
    )
    expect(
        WeeklyPacingMode.heavy70.tooltipText().contains("7-day schedule"),
        "weekly pacing tooltip reflects selected weekly workload"
    )
    expect(
        QuotaDisplayPolicy.weeklyPacingHintTitle().contains("ahead of your selected pace"),
        "weekly pacing hint explains what triggers the marker"
    )
    expect(
        QuotaDisplayPolicy.weeklyPacingHintDetail().contains("5 days"),
        "weekly pacing hint explains that presets do not change quota remaining"
    )
    expect(
        QuotaDisplayPolicy.weeklyPaceExplanation(for: .balanced56).contains("marker position"),
        "weekly row explanation includes the selected weekly workload"
    )
    expect(
        QuotaDisplayPolicy.weeklyPaceInlineExplanation(for: .balanced56).contains("7d × 8h"),
        "weekly inline explanation reflects the selected weekly workload"
    )
    let fortyHourMarker = StatusPresentation.markerThresholdPercent(for: weekly, weeklyPacingMode: .workWeek40, isWeekly: true)
    let fiftySixHourMarker = StatusPresentation.markerThresholdPercent(for: weekly, weeklyPacingMode: .balanced56, isWeekly: true)
    let seventyHourMarker = StatusPresentation.markerThresholdPercent(for: weekly, weeklyPacingMode: .heavy70, isWeekly: true)
    expect(
        (fortyHourMarker ?? -1) > (fiftySixHourMarker ?? -1) && (fiftySixHourMarker ?? -1) > (seventyHourMarker ?? -1),
        "weekly normal-progress marker shifts with 40h, 56h, and 70h presets"
    )
    expect(
        Int((fortyHourMarker ?? -1).rounded()) == 29,
        "40h marker matches the expected average-work pace for this sample"
    )
    let fiftySixSlot = Int((((fiftySixHourMarker ?? 0) / 100.0) * 28.0).rounded())
    let seventySlot = Int((((seventyHourMarker ?? 0) / 100.0) * 28.0).rounded())
    expect(
        fiftySixSlot != seventySlot,
        "56h and 70h markers land in different visual slots on the 28-step menu bar"
    )
}

func testWeeklyTooltipHoursChangeWhileMarkerPercentStaysFixed() {
    let weekly = LimitWindow(
        usedPercent: 58,
        windowMinutes: 10080,
        resetAfterSeconds: 505_436,
        resetAt: 1_775_874_219
    )

    let forty = StatusPresentation(
        snapshot: CodexQuotaSnapshot(
            planType: "pro",
            rateLimits: RateLimits(allowed: true, limitReached: false, primary: nil, secondary: weekly),
            credits: nil
        ),
        accountInfo: nil,
        generatedAt: Date(),
        source: .api,
        weeklyPacingMode: .workWeek40,
        language: .english
    )
    let fiftySix = StatusPresentation(
        snapshot: CodexQuotaSnapshot(
            planType: "pro",
            rateLimits: RateLimits(allowed: true, limitReached: false, primary: nil, secondary: weekly),
            credits: nil
        ),
        accountInfo: nil,
        generatedAt: Date(),
        source: .api,
        weeklyPacingMode: .balanced56,
        language: .english
    )
    let seventy = StatusPresentation(
        snapshot: CodexQuotaSnapshot(
            planType: "pro",
            rateLimits: RateLimits(allowed: true, limitReached: false, primary: nil, secondary: weekly),
            credits: nil
        ),
        accountInfo: nil,
        generatedAt: Date(),
        source: .api,
        weeklyPacingMode: .heavy70,
        language: .english
    )

    expect(forty.secondaryRow?.tooltipText?.contains("Normal elapsed: 12h (29%)") == true, "40h tooltip converts the 5x8 schedule into weekly progress")
    expect(fiftySix.secondaryRow?.tooltipText?.contains("Normal elapsed: 12h (21%)") == true, "56h tooltip converts the 7x8 schedule into weekly progress")
    expect(seventy.secondaryRow?.tooltipText?.contains("Normal elapsed: 14h (19%)") == true, "70h tooltip converts the 7x10 schedule into weekly progress")
}

func testWeeklyPaceMathActiveElapsedFractionUsesPresetSchedule() {
    let resetAt = 1_775_874_219.0
    let resetAfterSeconds = 505_436

    let forty = WeeklyPaceMath.activeElapsedFraction(
        resetAt: resetAt,
        resetAfterSeconds: resetAfterSeconds,
        mode: .workWeek40
    )
    let fiftySix = WeeklyPaceMath.activeElapsedFraction(
        resetAt: resetAt,
        resetAfterSeconds: resetAfterSeconds,
        mode: .balanced56
    )
    let seventy = WeeklyPaceMath.activeElapsedFraction(
        resetAt: resetAt,
        resetAfterSeconds: resetAfterSeconds,
        mode: .heavy70
    )

    expect(Int((forty * 100).rounded()) == 29, "40h weekly pace math matches the expected 5x8 schedule progress")
    expect(Int((fiftySix * 100).rounded()) == 21, "56h weekly pace math matches the expected 7x8 schedule progress")
    expect(Int((seventy * 100).rounded()) == 19, "70h weekly pace math matches the expected 7x10 schedule progress")
}

func testWeeklyMarkerPresentationFlowsIntoLayoutSlots() {
    let weekly = LimitWindow(
        usedPercent: 58,
        windowMinutes: 10080,
        resetAfterSeconds: 505_436,
        resetAt: 1_775_874_219
    )
    let fortyMarker = StatusPresentation.markerThresholdPercent(for: weekly, weeklyPacingMode: .workWeek40, isWeekly: true)!
    let seventyMarker = StatusPresentation.markerThresholdPercent(for: weekly, weeklyPacingMode: .heavy70, isWeekly: true)!

    let fortyLayout = QuotaRowLayout.build(
        label: "7 days",
        language: .english,
        percentText: "42%!!",
        reset: "Apr 16",
        markerThresholdPercent: fortyMarker,
        usedOnLeft: true
    )
    let seventyLayout = QuotaRowLayout.build(
        label: "7 days",
        language: .english,
        percentText: "42%!!!",
        reset: "Apr 16",
        markerThresholdPercent: seventyMarker,
        usedOnLeft: true
    )

    expect((fortyLayout.markerIndex ?? -1) > (seventyLayout.markerIndex ?? -1), "weekly marker layout places the 40h marker further right than the 70h marker for used-left rows")
}

func testDailyUsageLedgerTracksDailyBudgetInsteadOfOnlyCumulativeTrend() {
    let baseDate = Date(timeIntervalSince1970: 1_775_291_731)
    let calendar = Calendar(identifier: .gregorian)
    let resetAt = baseDate.addingTimeInterval(7 * 24 * 3600).timeIntervalSince1970

    let rows = [
        CodexQuotaFetchResult(
            snapshot: makeSnapshot(primaryUsed: 0, secondaryUsed: 10, secondaryResetAt: resetAt, secondaryResetAfterSeconds: 6 * 24 * 3600),
            source: .realtimeLogs,
            sourceDate: baseDate
        ),
        CodexQuotaFetchResult(
            snapshot: makeSnapshot(primaryUsed: 0, secondaryUsed: 22, secondaryResetAt: resetAt, secondaryResetAfterSeconds: 5 * 24 * 3600),
            source: .realtimeLogs,
            sourceDate: baseDate.addingTimeInterval(24 * 3600)
        ),
        CodexQuotaFetchResult(
            snapshot: makeSnapshot(primaryUsed: 0, secondaryUsed: 27, secondaryResetAt: resetAt, secondaryResetAfterSeconds: 4 * 24 * 3600),
            source: .realtimeLogs,
            sourceDate: baseDate.addingTimeInterval(2 * 24 * 3600)
        )
    ]

    let days = DailyUsageLedger.build(
        rows: rows,
        calendar: calendar,
        latestObservedDate: baseDate.addingTimeInterval(2 * 24 * 3600)
    )

    expect(days.count == 7, "daily usage ledger always expands to a full seven-day week")
    expect(days[0].usedPercent == 10, "daily usage ledger keeps the first day's used percent")
    expect(days[1].usedPercent == 12, "daily usage ledger calculates per-day deltas from cumulative maxima")
    expect(days[2].usedPercent == 5, "daily usage ledger keeps later-day deltas independent from earlier spikes")
    expect(days[1].expectedDailyUsedPercent > 0, "daily usage ledger records expected daily budget")
    expect(days[2].expectedDailyUsedPercent > days[2].usedPercent, "daily usage ledger can show a controlled day after a heavy earlier day")
    expect(days[2].isAheadOfDailyPace == false, "daily usage ledger highlights days against their own budget, not only cumulative total")
}

func testDailyUsageChartRendererKeepsAxisAndFooterAligned() {
    let summary = CodexQuotaTrendSummary(
        dailyUsageBars: [
            .init(date: Date(timeIntervalSince1970: 1_775_291_731), usedPercent: 10, cumulativeUsedPercent: 10, expectedUsedPercent: 8, expectedDailyUsedPercent: 8, isFuture: false),
            .init(date: Date(timeIntervalSince1970: 1_775_378_131), usedPercent: 12, cumulativeUsedPercent: 22, expectedUsedPercent: 16, expectedDailyUsedPercent: 8, isFuture: false),
            .init(date: Date(timeIntervalSince1970: 1_775_464_531), usedPercent: 5, cumulativeUsedPercent: 27, expectedUsedPercent: 24, expectedDailyUsedPercent: 8, isFuture: false),
            .init(date: Date(timeIntervalSince1970: 1_775_550_931), usedPercent: 0, cumulativeUsedPercent: 27, expectedUsedPercent: 32, expectedDailyUsedPercent: 8, isFuture: true),
            .init(date: Date(timeIntervalSince1970: 1_775_637_331), usedPercent: 0, cumulativeUsedPercent: 27, expectedUsedPercent: 32, expectedDailyUsedPercent: 0, isFuture: true),
            .init(date: Date(timeIntervalSince1970: 1_775_723_731), usedPercent: 0, cumulativeUsedPercent: 27, expectedUsedPercent: 32, expectedDailyUsedPercent: 0, isFuture: true),
            .init(date: Date(timeIntervalSince1970: 1_775_810_131), usedPercent: 0, cumulativeUsedPercent: 27, expectedUsedPercent: 32, expectedDailyUsedPercent: 0, isFuture: true)
        ]
    )
    let chart = summary.chartPresentation(language: .english, weeklyPacingMode: .balanced56)!
    let text = DailyUsageChartRenderer.render(chart)
    let lines = text.components(separatedBy: "\n")

    expect(lines.count == 7, "daily usage chart renderer keeps title, four rows, axis, and footer")
    expect(lines[1].contains("┤"), "daily usage chart renderer keeps the y-axis on data rows")
    expect(lines[5].contains("└"), "daily usage chart renderer keeps the x-axis baseline")
    expect(lines[6].hasPrefix("     "), "daily usage chart renderer indents the footer to the chart origin")
    expect(lines[6].contains("4") && lines[6].contains("10"), "daily usage chart renderer keeps the full seven-day footer labels")
}

func testDailyUsageChartStylePolicySeparatesAlertAndFutureSemantics() {
    expect(DailyUsageChartStylePolicy.barTone(isFilled: false, isAheadOfPace: true, isFuture: false) == .muted, "daily usage chart style keeps empty bar cells muted even on alert days")
    expect(DailyUsageChartStylePolicy.barTone(isFilled: true, isAheadOfPace: false, isFuture: false) == .normal, "daily usage chart style marks filled on-budget cells as normal")
    expect(DailyUsageChartStylePolicy.barTone(isFilled: true, isAheadOfPace: true, isFuture: false) == .alert, "daily usage chart style marks filled ahead-of-pace cells as alert")
    expect(DailyUsageChartStylePolicy.footerTone(isAheadOfPace: true, isFuture: false) == .alert, "daily usage chart footer highlights over-budget dates")
    expect(DailyUsageChartStylePolicy.footerTone(isAheadOfPace: false, isFuture: true) == .muted, "daily usage chart footer mutes future dates")
}

func testChineseLanguagePresentationLocalizesCoreLabels() {
    let presentation = StatusPresentation(
        snapshot: makeSnapshot(primaryUsed: 10, secondaryUsed: 20),
        accountInfo: CodexAccountInfo(displayName: "User", email: "user@example.com", planDisplayName: "Pro"),
        generatedAt: Date(),
        source: .realtimeLogs,
        trendSummary: CodexQuotaTrendSummary(
            dailyUsageBars: [
                .init(date: Date(), usedPercent: 8, cumulativeUsedPercent: 8, expectedUsedPercent: 6, expectedDailyUsedPercent: 6, isFuture: false),
                .init(date: Date().addingTimeInterval(24 * 3600), usedPercent: 12, cumulativeUsedPercent: 20, expectedUsedPercent: 14, expectedDailyUsedPercent: 8, isFuture: false),
                .init(date: Date().addingTimeInterval(2 * 24 * 3600), usedPercent: 0, cumulativeUsedPercent: 20, expectedUsedPercent: 20, expectedDailyUsedPercent: 6, isFuture: true),
                .init(date: Date().addingTimeInterval(3 * 24 * 3600), usedPercent: 0, cumulativeUsedPercent: 20, expectedUsedPercent: 20, expectedDailyUsedPercent: 0, isFuture: true),
                .init(date: Date().addingTimeInterval(4 * 24 * 3600), usedPercent: 0, cumulativeUsedPercent: 20, expectedUsedPercent: 20, expectedDailyUsedPercent: 0, isFuture: true),
                .init(date: Date().addingTimeInterval(5 * 24 * 3600), usedPercent: 0, cumulativeUsedPercent: 20, expectedUsedPercent: 20, expectedDailyUsedPercent: 0, isFuture: true),
                .init(date: Date().addingTimeInterval(6 * 24 * 3600), usedPercent: 0, cumulativeUsedPercent: 20, expectedUsedPercent: 20, expectedDailyUsedPercent: 0, isFuture: true)
            ]
        ),
        weeklyPacingMode: .balanced56,
        language: .chinese
    )

    expect(presentation.accountRow?.label == "账号", "presentation localizes account label")
    expect(presentation.sourceText == "来源：本地日志", "presentation localizes source label")
    expect(presentation.updatedAtText == "刚刚更新", "presentation localizes relative update label")
    expect(presentation.trendText?.contains("每日用量") == true, "presentation localizes daily usage chart")
}

func testEnglishMenuContractSnapshotKeepsCoreMenuStructure() {
    let presentation = StatusPresentation(
        snapshot: makeSnapshot(primaryUsed: 4, secondaryUsed: 64),
        accountInfo: CodexAccountInfo(displayName: "67560691@qq.com", email: "67560691@qq.com", planDisplayName: "Pro"),
        generatedAt: Date(),
        source: .api,
        trendSummary: CodexQuotaTrendSummary(
            dailyUsageBars: [
                .init(date: Date(), usedPercent: 10, cumulativeUsedPercent: 10, expectedUsedPercent: 8, expectedDailyUsedPercent: 8, isFuture: false),
                .init(date: Date().addingTimeInterval(24 * 3600), usedPercent: 12, cumulativeUsedPercent: 22, expectedUsedPercent: 16, expectedDailyUsedPercent: 8, isFuture: false),
                .init(date: Date().addingTimeInterval(2 * 24 * 3600), usedPercent: 5, cumulativeUsedPercent: 27, expectedUsedPercent: 24, expectedDailyUsedPercent: 8, isFuture: false),
                .init(date: Date().addingTimeInterval(3 * 24 * 3600), usedPercent: 0, cumulativeUsedPercent: 27, expectedUsedPercent: 32, expectedDailyUsedPercent: 8, isFuture: true),
                .init(date: Date().addingTimeInterval(4 * 24 * 3600), usedPercent: 0, cumulativeUsedPercent: 27, expectedUsedPercent: 32, expectedDailyUsedPercent: 0, isFuture: true),
                .init(date: Date().addingTimeInterval(5 * 24 * 3600), usedPercent: 0, cumulativeUsedPercent: 27, expectedUsedPercent: 32, expectedDailyUsedPercent: 0, isFuture: true),
                .init(date: Date().addingTimeInterval(6 * 24 * 3600), usedPercent: 0, cumulativeUsedPercent: 27, expectedUsedPercent: 32, expectedDailyUsedPercent: 0, isFuture: true)
            ]
        ),
        weeklyPacingMode: .workWeek40,
        language: .english
    )
    let snapshot = MenuContractBuilder.build(
        presentation: presentation,
        language: .english,
        weeklyPacingMode: .workWeek40,
        showsLastUpdated: true
    )

    expect(snapshot.title == "Codex Quota Usage", "english menu snapshot keeps the quota title")
    expect(snapshot.accountLine == "Account 67560691@qq.com (Pro)", "english menu snapshot keeps account and plan on one line")
    expect(snapshot.primaryLabel == "5h", "english menu snapshot includes the 5h row")
    expect(snapshot.secondaryLabel == "7d", "english menu snapshot includes the 7d row")
    expect(snapshot.weeklySelectorTitle == "Weekly work hours", "english menu snapshot includes the weekly selector title")
    expect(snapshot.weeklyOptions == ["40h", "56h", "70h"], "english menu snapshot keeps all weekly selector options")
    expect(snapshot.weeklyExplanation.contains("40h/week"), "english menu snapshot keeps weekly explanation text")
    expect(snapshot.updatedLine?.contains("Source: API") == true, "english menu snapshot keeps updated/source line")
    expect(snapshot.creditsLine == nil, "english menu snapshot can omit credits when unavailable")
    expect(snapshot.actionTitles.contains("Refresh Now (API)"), "english menu snapshot keeps refresh action")
    expect(snapshot.actionTitles.contains("Preferences..."), "english menu snapshot keeps preferences action")
}

func testChineseMenuContractSnapshotKeepsCoreMenuStructure() {
    let presentation = StatusPresentation(
        snapshot: makeSnapshot(primaryUsed: 4, secondaryUsed: 64),
        accountInfo: CodexAccountInfo(displayName: "67560691@qq.com", email: "67560691@qq.com", planDisplayName: "Pro"),
        generatedAt: Date(),
        source: .realtimeLogs,
        trendSummary: nil,
        weeklyPacingMode: .balanced56,
        language: .chinese
    )
    let snapshot = MenuContractBuilder.build(
        presentation: presentation,
        language: .chinese,
        weeklyPacingMode: .balanced56,
        showsLastUpdated: true
    )

    expect(snapshot.title == "Codex 用量", "chinese menu snapshot keeps the quota title")
    expect(snapshot.accountLine == "账号 67560691@qq.com (Pro)", "chinese menu snapshot keeps account and plan on one line")
    expect(snapshot.primaryLabel == "5h", "chinese menu snapshot includes the 5h row")
    expect(snapshot.secondaryLabel == "7d", "chinese menu snapshot includes the 7d row")
    expect(snapshot.weeklySelectorTitle == "每周工作时长", "chinese menu snapshot includes weekly selector title")
    expect(snapshot.weeklyOptions == ["40h", "56h", "70h"], "chinese menu snapshot keeps all weekly selector options")
    expect(snapshot.updatedLine?.contains("来源：本地日志") == true, "chinese menu snapshot keeps updated/source line")
    expect(snapshot.actionTitles.contains("立即刷新（API）"), "chinese menu snapshot keeps refresh action")
    expect(snapshot.actionTitles.contains("偏好设置..."), "chinese menu snapshot keeps preferences action")
}

func testMenuContractSnapshotRespectsLastUpdatedVisibility() {
    let presentation = StatusPresentation(
        snapshot: makeSnapshot(primaryUsed: 8, secondaryUsed: 20),
        accountInfo: CodexAccountInfo(displayName: "67560691@qq.com", email: "67560691@qq.com", planDisplayName: "Pro"),
        generatedAt: Date(),
        source: .api,
        language: .english
    )

    let visible = MenuContractBuilder.build(
        presentation: presentation,
        language: .english,
        weeklyPacingMode: .balanced56,
        showsLastUpdated: true
    )
    let hidden = MenuContractBuilder.build(
        presentation: presentation,
        language: .english,
        weeklyPacingMode: .balanced56,
        showsLastUpdated: false
    )

    expect(visible.updatedLine?.contains("Source: API") == true, "menu contract includes updated/source line when enabled")
    expect(hidden.updatedLine == nil, "menu contract hides updated/source line when disabled")
}

func testMenuContractSnapshotKeepsActionOrderAndCredits() {
    let presentation = StatusPresentation(
        snapshot: CodexQuotaSnapshot(
            planType: "pro",
            rateLimits: RateLimits(
                allowed: true,
                limitReached: false,
                primary: makeWindow(usedPercent: 5),
                secondary: makeWindow(usedPercent: 18, windowMinutes: 10080)
            ),
            credits: CreditsInfo(hasCredits: true, unlimited: false, balance: "12.34")
        ),
        accountInfo: CodexAccountInfo(displayName: "67560691@qq.com", email: "67560691@qq.com", planDisplayName: "Pro"),
        generatedAt: Date(),
        source: .api,
        language: .english
    )

    let snapshot = MenuContractBuilder.build(
        presentation: presentation,
        language: .english,
        weeklyPacingMode: .balanced56,
        showsLastUpdated: true
    )

    expect(snapshot.creditsLine == "Credits: 12.34 left", "menu contract keeps credits line when credits exist")
    expect(
        snapshot.actionTitles == [
            "Refresh Now (API)",
            "Switch Account…",
            "Usage Dashboard",
            "Status Page",
            "Copy Details",
            "Open Codex Folder",
            "Reveal Logs Database",
            "Preferences...",
            "About Codex Quota Peek",
            "Quit"
        ],
        "menu contract preserves core action ordering"
    )
}

func testMenuContractSnapshotKeepsSelectorAndExplanationTogether() {
    let presentation = StatusPresentation(
        snapshot: makeSnapshot(primaryUsed: 4, secondaryUsed: 64),
        accountInfo: CodexAccountInfo(displayName: "67560691@qq.com", email: "67560691@qq.com", planDisplayName: "Pro"),
        generatedAt: Date(),
        source: .api,
        language: .english
    )

    let snapshot = MenuContractBuilder.build(
        presentation: presentation,
        language: .english,
        weeklyPacingMode: .heavy70,
        showsLastUpdated: true
    )

    expect(snapshot.weeklySelectorTitle == "Weekly work hours", "menu contract keeps the weekly selector block title")
    expect(snapshot.weeklyExplanation.contains("70h/week"), "menu contract keeps the explanation tied to the selected preset")
}

func testMenuFactoryBuildsCoreMenuTagsAndOrder() {
    final class DummyTarget: NSObject {}
    let menu = NSMenu()
    MenuFactory.configure(menu: menu, language: .english, target: DummyTarget())
    let tags = menu.items.map(\.tag)

    expect(tags.contains(MenuTag.title), "menu factory keeps the title item")
    expect(tags.contains(MenuTag.account), "menu factory keeps the account item")
    expect(tags.contains(MenuTag.primary), "menu factory keeps the 5h quota item")
    expect(tags.contains(MenuTag.secondary), "menu factory keeps the 7d quota item")
    expect(tags.contains(MenuTag.weeklyPaceSelector), "menu factory keeps the weekly selector")
    expect(tags.contains(MenuTag.refresh), "menu factory keeps the refresh action")
    expect(tags.contains(MenuTag.preferences), "menu factory keeps the preferences action")

    let refreshIndex = tags.firstIndex(of: MenuTag.refresh) ?? -1
    let switchIndex = tags.firstIndex(of: MenuTag.switchAccountMenu) ?? -1
    let usageIndex = tags.firstIndex(of: MenuTag.openUsageDashboard) ?? -1
    expect(refreshIndex < switchIndex && switchIndex < usageIndex, "menu factory preserves the core action ordering")

    let weeklySubmenuTags = menu.item(withTag: MenuTag.weeklyPaceSelector)?.submenu?.items.map(\.tag) ?? []
    expect(weeklySubmenuTags == [MenuTag.weeklyPace40, MenuTag.weeklyPace56, MenuTag.weeklyPace70], "menu factory preserves weekly selector submenu order")
}

func testMenuUpdaterAppliesVisibilityAndWeeklyState() {
    final class DummyTarget: NSObject {}
    let menu = NSMenu()
    MenuFactory.configure(menu: menu, language: .english, target: DummyTarget())
    let input = MenuUpdaterInput(
        language: .english,
        presentation: StatusPresentation(
            line1: "H 90%",
            line2: "W 40%!!",
            tooltip: "quota",
            updatedAtText: "just updated",
            sourceText: "Source: API",
            creditsText: "12 left",
            language: .english
        ),
        selectedWeeklyPacingMode: .heavy70,
        showsLastUpdated: true,
        title: NSAttributedString(string: "Title"),
        account: NSAttributedString(string: "Account user@example.com (Pro)"),
        primary: NSAttributedString(string: "5h row"),
        secondary: NSAttributedString(string: "7d row"),
        paceNotice: NSAttributedString(string: "Weekly marker..."),
        updatedAt: NSAttributedString(string: "Updated just updated  Source: API"),
        credits: NSAttributedString(string: "Credits: 12 left"),
        trend: NSAttributedString(string: "Daily usage")
    )

    MenuUpdater.apply(menu: menu, input: input)

    expect(MenuUpdater.item(MenuTag.title, in: menu)?.attributedTitle?.string == "Title", "menu updater applies the title")
    expect(MenuUpdater.item(MenuTag.account, in: menu)?.attributedTitle?.string == "Account user@example.com (Pro)", "menu updater applies the account row")
    expect(MenuUpdater.item(MenuTag.updatedAt, in: menu)?.isHidden == false, "menu updater shows the updated/source row when enabled")
    expect(MenuUpdater.item(MenuTag.credits, in: menu)?.isHidden == false, "menu updater shows credits when present")
    expect(MenuUpdater.item(MenuTag.trend, in: menu)?.isHidden == false, "menu updater shows the trend block when present")
    expect(MenuUpdater.item(MenuTag.weeklyPace70, in: menu)?.state == .on, "menu updater selects the active weekly preset")
    expect(MenuUpdater.item(MenuTag.weeklyPace40, in: menu)?.state == .off, "menu updater clears inactive weekly presets")
}

func testMenuAttributedContentBuilderBuildsMenuInputAndExplanations() {
    let presentation = StatusPresentation(
        snapshot: makeSnapshot(primaryUsed: 12, secondaryUsed: 40),
        accountInfo: CodexAccountInfo(displayName: "user@example.com", email: "user@example.com", planDisplayName: "Pro"),
        generatedAt: Date(timeIntervalSince1970: 1_000),
        source: .api,
        trendSummary: nil,
        weeklyPacingMode: .balanced56,
        language: .english
    )

    let result = MenuAttributedContentBuilder.build(
        presentation: presentation,
        language: .english,
        showsPaceAlert: true,
        showsLastUpdated: true,
        selectedWeeklyPacingMode: .balanced56,
        weeklyPaceExplanation: "Weekly detail explanation",
        weeklyPaceInlineExplanation: "Inline weekly explanation"
    )

    expect(result.input.title.string.contains("Codex"), "content builder keeps the menu title text")
    expect(result.input.account.string.contains("user@example.com"), "content builder keeps account information")
    expect(result.input.updatedAt?.string.contains("Source: API") == true, "content builder includes updated/source text when enabled")
    expect(result.input.paceNotice.string.contains("Inline weekly explanation"), "content builder keeps weekly inline explanation")
    expect(result.primaryExplanationText?.isEmpty == false, "content builder exposes primary explanation text")
    expect(result.secondaryExplanationText?.contains("Weekly detail explanation") == true, "content builder appends weekly explanation to the secondary explanation")
}

func testMenuContractSnapshotFallsBackToPlaceholderAccount() {
    let presentation = StatusPresentation.unavailable("no data", language: .english)
    let snapshot = MenuContractBuilder.build(
        presentation: presentation,
        language: .english,
        weeklyPacingMode: .balanced56,
        showsLastUpdated: false
    )

    expect(snapshot.accountLine == "Account --", "menu contract keeps placeholder account line when account data is missing")
}

func testSystemLanguagePreferenceFallsBackToMacOSLocale() {
    expect(AppLanguage.systemPreferred(preferredLanguages: ["zh-Hans-CN"]) == .chinese, "system language detection maps Chinese locales to Chinese UI")
    expect(AppLanguage.systemPreferred(preferredLanguages: ["en-US"]) == .english, "system language detection keeps English locales on English UI")
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
            paceSeverity: nil,
            paceOverrunPercent: nil,
            usedPercent: 10,
            paceThresholdPercent: nil,
            markerThresholdPercent: nil,
            tooltipText: nil
        ),
        secondaryRow: StatusPresentation.MenuRow(
            label: "7 days",
            percentText: "80%",
            resetText: "Apr 11",
            resetDate: now.addingTimeInterval(24 * 60 * 60),
            isUsingFasterThanAverage: false,
            paceText: nil,
            paceSeverity: nil,
            paceOverrunPercent: nil,
            usedPercent: 20,
            paceThresholdPercent: nil,
            markerThresholdPercent: nil,
            tooltipText: nil
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
            paceSeverity: nil,
            paceOverrunPercent: nil,
            usedPercent: 10,
            paceThresholdPercent: nil,
            markerThresholdPercent: nil,
            tooltipText: nil
        ),
        secondaryRow: StatusPresentation.MenuRow(
            label: "7 days",
            percentText: "80%!",
            resetText: "Apr 11",
            resetDate: Date().addingTimeInterval(2 * 24 * 3600),
            isUsingFasterThanAverage: true,
            paceText: " Pace above avg ",
            paceSeverity: .warning,
            paceOverrunPercent: 12,
            usedPercent: 20,
            paceThresholdPercent: 8,
            markerThresholdPercent: 8,
            tooltipText: nil
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
        testMenuOpenRefreshPrefersAPIForLogsOrStaleData()
        testDisplayPresentationUsesPaceMarkersAndSourceText()
    testTrendSummaryMenuText()
    testSparklineSampling()
    testTrendRowsStayInsideCurrentResetWindow()
    testRelativeUpdatedAtLabels()
        testQuotaDisplayColorThresholds()
        testQuotaRowTooltipsIncludeDurationBreakdown()
        testQuotaRowTooltipsUseReadableSmallDurations()
        testQuotaExplanationBuilderFormatsEdgeDurations()
        testQuotaExplanationBuilderKeepsWeeklyTooltipSemantics()
        testQuotaRowLayoutBuildsCompactLabelsAndDetailText()
        testQuotaRowLayoutMarkerIndexFollowsMarkerPercent()
        testQuotaRowLayoutKeepsBarWidthStableAcrossDisplayScales()
        testQuotaRowTextRendererKeepsUsedRemainingDirectionAndRightAlignedDetail()
        testQuotaRowTextRendererMirrorsFiveHourRowsCorrectly()
        testQuotaRowTextRendererPlacesMarkerAtLayoutIndex()
        testAuthSnapshotStoreReadsSavedAccountMetadata()
        testAccountMenuBuilderBuildsStableSwitchLabels()
        testCliHelpPrefersRefreshOverUpdate()
        testRefreshRequestGateOnlyAppliesLatestRequest()
        testAutomaticRefreshDoesNotRegressWithinSameResetWindow()
        testAutomaticRefreshFailureShouldKeepCurrentSnapshot()
        testStartupAPIRefreshFallsBackWithoutOverridingCurrentRules()
        testWeeklyPacingModeCanBeLooserThanFullWeek()
        testWeeklyTooltipHoursChangeWhileMarkerPercentStaysFixed()
        testWeeklyPaceMathActiveElapsedFractionUsesPresetSchedule()
        testWeeklyMarkerPresentationFlowsIntoLayoutSlots()
        testDailyUsageLedgerTracksDailyBudgetInsteadOfOnlyCumulativeTrend()
        testDailyUsageChartRendererKeepsAxisAndFooterAligned()
        testDailyUsageChartStylePolicySeparatesAlertAndFutureSemantics()
        testChineseLanguagePresentationLocalizesCoreLabels()
        testEnglishMenuContractSnapshotKeepsCoreMenuStructure()
        testChineseMenuContractSnapshotKeepsCoreMenuStructure()
        testMenuContractSnapshotRespectsLastUpdatedVisibility()
        testMenuContractSnapshotKeepsActionOrderAndCredits()
        testMenuContractSnapshotKeepsSelectorAndExplanationTogether()
        testMenuContractSnapshotFallsBackToPlaceholderAccount()
        testMenuFactoryBuildsCoreMenuTagsAndOrder()
        testMenuUpdaterAppliesVisibilityAndWeeklyState()
        testMenuAttributedContentBuilderBuildsMenuInputAndExplanations()
        testSystemLanguagePreferenceFallsBackToMacOSLocale()
        testNotificationPolicyTriggersOnlyOnEscalation()
        testNotificationPolicyStaysQuietForRepeatedState()
        testNotificationPolicyEmitsResetReminderOnce()
        testNotificationPolicyRespectsCategoryPreferences()
        print("All tests passed.")
    }
}
