import Foundation

struct CodexQuotaSnapshot: Decodable {
    let planType: String?
    let rateLimits: RateLimits
    let credits: CreditsInfo?

    enum CodingKeys: String, CodingKey {
        case planType = "plan_type"
        case rateLimits = "rate_limits"
        case credits
    }
}

struct CreditsInfo: Decodable {
    let hasCredits: Bool?
    let unlimited: Bool?
    let balance: String?

    enum CodingKeys: String, CodingKey {
        case hasCredits = "has_credits"
        case unlimited
        case balance
    }
}

struct RateLimits: Decodable {
    let allowed: Bool?
    let limitReached: Bool?
    let primary: LimitWindow?
    let secondary: LimitWindow?

    enum CodingKeys: String, CodingKey {
        case allowed
        case limitReached = "limit_reached"
        case primary
        case secondary
    }
}

struct LimitWindow: Decodable {
    let usedPercent: Double
    let windowMinutes: Int?
    let resetAfterSeconds: Int?
    let resetAt: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case windowMinutes = "window_minutes"
        case resetAfterSeconds = "reset_after_seconds"
        case resetAt = "reset_at"
    }

    var remainingPercent: Int {
        max(0, min(100, Int((100.0 - usedPercent).rounded())))
    }

    var resetDate: Date? {
        guard let resetAt else { return nil }
        return Date(timeIntervalSince1970: resetAt)
    }

    var usedRoundedPercent: Int {
        max(0, min(100, Int(usedPercent.rounded())))
    }

    var elapsedFraction: Double? {
        guard let windowMinutes, let resetAfterSeconds else { return nil }
        let totalSeconds = Double(windowMinutes * 60)
        guard totalSeconds > 0 else { return nil }
        let remainingSeconds = min(max(Double(resetAfterSeconds), 0), totalSeconds)
        let elapsedSeconds = totalSeconds - remainingSeconds
        return min(max(elapsedSeconds / totalSeconds, 0), 1)
    }

    var isUsingFasterThanAverage: Bool {
        guard let elapsedFraction else { return false }
        return usedPercent > elapsedFraction * 100.0
    }
}

struct StatusPresentation {
    enum PaceSeverity {
        case warning
        case critical
        case severe
    }

    struct AccountRow {
        let label: String
        let value: String
    }

    struct MenuRow {
        let label: String
        let percentText: String
        let resetText: String
        let resetDate: Date?
        let isUsingFasterThanAverage: Bool
        let paceText: String?
        let paceSeverity: PaceSeverity?
        let paceOverrunPercent: Double?
        let usedPercent: Double
        let paceThresholdPercent: Double?
        let markerThresholdPercent: Double?
        let tooltipText: String?
    }

    let line1: String
    let line2: String
    let tooltip: String
    let accountRow: AccountRow?
    let planRow: AccountRow?
    let primaryRow: MenuRow?
    let secondaryRow: MenuRow?
    let paceMessage: String?
    let paceSeverity: PaceSeverity?
    let trendText: String?
    let trendSummary: CodexQuotaTrendSummary?
    let sparklineText: String?
    let updatedAtText: String
    let sourceText: String
    let creditsText: String?
    let language: AppLanguage

    init(
        line1: String,
        line2: String,
        tooltip: String,
        accountRow: AccountRow? = nil,
        planRow: AccountRow? = nil,
        primaryRow: MenuRow? = nil,
        secondaryRow: MenuRow? = nil,
        paceMessage: String? = nil,
        paceSeverity: PaceSeverity? = nil,
        trendText: String? = nil,
        trendSummary: CodexQuotaTrendSummary? = nil,
        sparklineText: String? = nil,
        updatedAtText: String = "--",
        sourceText: String = "Source: local logs",
        creditsText: String? = nil,
        language: AppLanguage = .english
    ) {
        self.line1 = line1
        self.line2 = line2
        self.tooltip = tooltip
        self.accountRow = accountRow
        self.planRow = planRow
        self.primaryRow = primaryRow
        self.secondaryRow = secondaryRow
        self.paceMessage = paceMessage
        self.paceSeverity = paceSeverity
        self.trendText = trendText
        self.trendSummary = trendSummary
        self.sparklineText = sparklineText
        self.updatedAtText = updatedAtText
        self.sourceText = sourceText
        self.creditsText = creditsText
        self.language = language
    }

    static let loading = StatusPresentation(
        line1: "H --",
        line2: "W --",
        tooltip: AppLanguage.english.loadingTooltip,
        language: .english
    )

    static func unavailable(_ reason: String, language: AppLanguage = .english) -> StatusPresentation {
        StatusPresentation(
            line1: "H --",
            line2: "W --",
            tooltip: reason,
        paceMessage: nil,
        paceSeverity: nil,
        trendSummary: nil,
        updatedAtText: "--",
            sourceText: language.unavailableSourceText,
            creditsText: nil,
            language: language
        )
    }

    init(
        snapshot: CodexQuotaSnapshot,
        accountInfo: CodexAccountInfo?,
        generatedAt: Date,
        source: CodexQuotaFetchSource,
        trendSummary: CodexQuotaTrendSummary? = nil,
        weeklyPacingMode: WeeklyPacingMode = .balanced56,
        language: AppLanguage = .english,
        now: Date = Date()
    ) {
        let primary = snapshot.rateLimits.primary
        let secondary = snapshot.rateLimits.secondary

        line1 = primary.map { "H \(StatusPresentation.statusPercentText(for: $0))" } ?? "H --"
        line2 = secondary.map { "W \(StatusPresentation.statusPercentText(for: $0, weeklyPacingMode: weeklyPacingMode, isWeekly: true))" } ?? "W --"
        accountRow = accountInfo.map {
            AccountRow(label: language.accountLabel, value: $0.email ?? $0.displayName)
        }
        planRow = accountInfo.map {
            AccountRow(label: language.planLabel, value: $0.planDisplayName)
        }
        primaryRow = primary.map {
            MenuRow(
                label: StatusPresentation.windowLabel(for: $0, language: language),
                percentText: StatusPresentation.statusPercentText(for: $0),
                resetText: StatusPresentation.resetLabel(for: $0),
                resetDate: $0.resetDate,
                isUsingFasterThanAverage: $0.isUsingFasterThanAverage,
                paceText: StatusPresentation.inlinePaceText(for: $0, language: language),
                paceSeverity: StatusPresentation.paceSeverity(for: $0),
                paceOverrunPercent: StatusPresentation.overAverageOffset(for: $0),
                usedPercent: $0.usedPercent,
                paceThresholdPercent: StatusPresentation.pacingThresholdPercent(for: $0, weeklyPacingMode: weeklyPacingMode, isWeekly: false),
                markerThresholdPercent: StatusPresentation.markerThresholdPercent(for: $0, weeklyPacingMode: weeklyPacingMode, isWeekly: false),
                tooltipText: StatusPresentation.rowTooltip(for: $0, language: language)
            )
        }
        secondaryRow = secondary.map {
            MenuRow(
                label: StatusPresentation.windowLabel(for: $0, language: language),
                percentText: StatusPresentation.statusPercentText(for: $0, weeklyPacingMode: weeklyPacingMode, isWeekly: true),
                resetText: StatusPresentation.resetLabel(for: $0),
                resetDate: $0.resetDate,
                isUsingFasterThanAverage: StatusPresentation.isUsingFasterThanAverage(for: $0, weeklyPacingMode: weeklyPacingMode, isWeekly: true),
                paceText: StatusPresentation.inlinePaceText(for: $0, weeklyPacingMode: weeklyPacingMode, isWeekly: true, language: language),
                paceSeverity: StatusPresentation.paceSeverity(for: $0, weeklyPacingMode: weeklyPacingMode, isWeekly: true),
                paceOverrunPercent: StatusPresentation.overAverageOffset(for: $0, weeklyPacingMode: weeklyPacingMode, isWeekly: true),
                usedPercent: $0.usedPercent,
                paceThresholdPercent: StatusPresentation.pacingThresholdPercent(for: $0, weeklyPacingMode: weeklyPacingMode, isWeekly: true),
                markerThresholdPercent: StatusPresentation.markerThresholdPercent(for: $0, weeklyPacingMode: weeklyPacingMode, isWeekly: true),
                tooltipText: StatusPresentation.rowTooltip(for: $0, weeklyPacingMode: weeklyPacingMode, isWeekly: true, language: language)
            )
        }
        paceMessage = StatusPresentation.paceMessage(primary: primary, secondary: secondary, weeklyPacingMode: weeklyPacingMode, language: language)
        paceSeverity = StatusPresentation.paceSeverity(primary: primary, secondary: secondary, weeklyPacingMode: weeklyPacingMode)
        trendText = trendSummary?.menuText(language: language, weeklyPacingMode: weeklyPacingMode)
        self.trendSummary = trendSummary
        sparklineText = trendSummary?.sparklineText(language: language)
        updatedAtText = StatusPresentation.relativeUpdatedAtLabel(for: generatedAt, now: now, language: language)
        creditsText = StatusPresentation.creditsText(for: snapshot.credits, language: language)
        sourceText = language.sourceText(for: source)
        self.language = language

        var parts: [String] = []
        if let accountInfo {
            parts.append("\(language.accountLabel): \(accountInfo.displayName)")
            if let email = accountInfo.email {
                parts.append((language == .english ? "Email" : "邮箱") + ": \(email)")
            }
            parts.append("\(language.planLabel): \(accountInfo.planDisplayName)")
        }
        if let plan = snapshot.planType {
            parts.append("\(language.planLabel): \(plan)")
        }
        if let primary {
            parts.append("\(StatusPresentation.windowLabel(for: primary, language: language)) \(language.leftLabel): \(StatusPresentation.statusPercentText(for: primary))")
            if let date = primary.resetDate {
                parts.append("\(StatusPresentation.windowLabel(for: primary, language: language)) \(language.resetsLabel.lowercased()): \(StatusPresentation.dateFormatter.string(from: date))")
            }
            if primary.isUsingFasterThanAverage, let elapsedFraction = primary.elapsedFraction {
                parts.append("\(StatusPresentation.windowLabel(for: primary, language: language)) pace: \(Int((elapsedFraction * 100).rounded()))% elapsed, \(primary.usedRoundedPercent)% used")
            }
        }
        if let secondary {
            parts.append("\(StatusPresentation.windowLabel(for: secondary, language: language)) \(language.leftLabel): \(StatusPresentation.statusPercentText(for: secondary))")
            if let date = secondary.resetDate {
                parts.append("\(StatusPresentation.windowLabel(for: secondary, language: language)) \(language.resetsLabel.lowercased()): \(StatusPresentation.dateFormatter.string(from: date))")
            }
            if secondary.isUsingFasterThanAverage, let elapsedFraction = secondary.elapsedFraction {
                parts.append("\(StatusPresentation.windowLabel(for: secondary, language: language)) pace: \(Int((elapsedFraction * 100).rounded()))% elapsed, \(secondary.usedRoundedPercent)% used")
            }
        }
        if let paceMessage {
            parts.append((language == .english ? "Pace alert" : "节奏提醒") + ": \(paceMessage)")
        }
        if let creditsText {
            parts.append("\(language.creditsLabel): \(creditsText)")
        }
        if let trendText {
            parts.append(trendText)
        }
        if let sparklineText {
            parts.append(sparklineText)
        }
        parts.append(sourceText)
        parts.append("\(language.updatedPrefix): \(StatusPresentation.dateFormatter.string(from: generatedAt))")
        tooltip = parts.joined(separator: "\n")
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter
    }()

    private static func windowLabel(for window: LimitWindow, language: AppLanguage = .english) -> String {
        language.windowLabel(for: window.windowMinutes)
    }

    private static func resetLabel(for window: LimitWindow) -> String {
        guard let date = window.resetDate else { return "--" }
        if let minutes = window.windowMinutes, minutes <= 1440 {
            return timeFormatter.string(from: date)
        }
        return shortDateFormatter.string(from: date)
    }

    static func statusPercentText(
        for window: LimitWindow,
        weeklyPacingMode: WeeklyPacingMode = .balanced56,
        isWeekly: Bool = false
    ) -> String {
        "\(window.remainingPercent)%\(paceMarker(for: window, weeklyPacingMode: weeklyPacingMode, isWeekly: isWeekly))"
    }

    private static func paceMessage(
        primary: LimitWindow?,
        secondary: LimitWindow?,
        weeklyPacingMode: WeeklyPacingMode,
        language: AppLanguage = .english
    ) -> String? {
        var labels: [String] = []
        if let primary, isUsingFasterThanAverage(for: primary) {
            labels.append(QuotaDisplayPolicy.menuWindowTitle(for: windowLabel(for: primary, language: language)))
        }
        if let secondary, isUsingFasterThanAverage(for: secondary, weeklyPacingMode: weeklyPacingMode, isWeekly: true) {
            labels.append(QuotaDisplayPolicy.menuWindowTitle(for: windowLabel(for: secondary, language: language)))
        }

        return language.paceMessage(labels: labels)
    }

    private static func inlinePaceText(
        for window: LimitWindow,
        weeklyPacingMode: WeeklyPacingMode = .balanced56,
        isWeekly: Bool = false,
        language: AppLanguage = .english
    ) -> String? {
        guard isUsingFasterThanAverage(for: window, weeklyPacingMode: weeklyPacingMode, isWeekly: isWeekly) else { return nil }
        return language.paceAboveAverageText
    }

    private static func paceSeverity(
        primary: LimitWindow?,
        secondary: LimitWindow?,
        weeklyPacingMode: WeeklyPacingMode
    ) -> PaceSeverity? {
        let offsets = [
            overAverageOffset(for: primary),
            overAverageOffset(for: secondary, weeklyPacingMode: weeklyPacingMode, isWeekly: true)
        ].compactMap { $0 }
        guard let maxOffset = offsets.max() else { return nil }
        return paceSeverity(forOffset: maxOffset)
    }

    static func paceSeverity(
        for window: LimitWindow,
        weeklyPacingMode: WeeklyPacingMode = .balanced56,
        isWeekly: Bool = false
    ) -> PaceSeverity? {
        guard let offset = overAverageOffset(for: window, weeklyPacingMode: weeklyPacingMode, isWeekly: isWeekly) else { return nil }
        return paceSeverity(forOffset: offset)
    }

    private static func overAverageOffset(
        for window: LimitWindow?,
        weeklyPacingMode: WeeklyPacingMode = .balanced56,
        isWeekly: Bool = false
    ) -> Double? {
        guard let window,
              let thresholdPercent = pacingThresholdPercent(for: window, weeklyPacingMode: weeklyPacingMode, isWeekly: isWeekly),
              isUsingFasterThanAverage(for: window, weeklyPacingMode: weeklyPacingMode, isWeekly: isWeekly) else {
            return nil
        }
        let baseOffset = window.usedPercent - thresholdPercent
        if isWeekly {
            return baseOffset + weeklyPacingMode.paceSeverityBoost
        }
        return baseOffset
    }

    static func paceMarker(
        for window: LimitWindow,
        weeklyPacingMode: WeeklyPacingMode = .balanced56,
        isWeekly: Bool = false
    ) -> String {
        switch paceSeverity(for: window, weeklyPacingMode: weeklyPacingMode, isWeekly: isWeekly) {
        case .warning:
            return "!"
        case .critical:
            return "!!"
        case .severe:
            return "!!!"
        case nil:
            return ""
        }
    }

    private static func isUsingFasterThanAverage(
        for window: LimitWindow,
        weeklyPacingMode: WeeklyPacingMode = .balanced56,
        isWeekly: Bool = false
    ) -> Bool {
        guard let thresholdPercent = pacingThresholdPercent(for: window, weeklyPacingMode: weeklyPacingMode, isWeekly: isWeekly) else {
            return false
        }
        return window.usedPercent > thresholdPercent
    }

    static func pacingThresholdPercent(
        for window: LimitWindow,
        weeklyPacingMode: WeeklyPacingMode,
        isWeekly: Bool
    ) -> Double? {
        guard isWeekly else {
            return window.elapsedFraction.map { $0 * 100.0 }
        }

        return weeklyActiveElapsedFraction(for: window, weeklyPacingMode: weeklyPacingMode).map { $0 * 100.0 }
    }

    static func displayThresholdPercent(
        for window: LimitWindow,
        weeklyPacingMode: WeeklyPacingMode,
        isWeekly: Bool
    ) -> Double? {
        guard let base = pacingThresholdPercent(for: window, weeklyPacingMode: weeklyPacingMode, isWeekly: isWeekly) else {
            return nil
        }
        guard isWeekly else { return base }
        return min(100, max(0, base + weeklyPacingMode.displayThresholdAdjustment))
    }

    static func markerThresholdPercent(
        for window: LimitWindow,
        weeklyPacingMode: WeeklyPacingMode,
        isWeekly: Bool
    ) -> Double? {
        guard let base = pacingThresholdPercent(for: window, weeklyPacingMode: weeklyPacingMode, isWeekly: isWeekly) else {
            return nil
        }
        return min(100, max(0, base))
    }

    private static func weeklyActiveElapsedFraction(
        for window: LimitWindow,
        weeklyPacingMode: WeeklyPacingMode
    ) -> Double? {
        guard let resetAt = window.resetAt, let resetAfterSeconds = window.resetAfterSeconds else {
            return nil
        }
        return WeeklyPaceMath.activeElapsedFraction(
            resetAt: resetAt,
            resetAfterSeconds: resetAfterSeconds,
            mode: weeklyPacingMode
        )
    }

    private static func paceSeverity(forOffset offset: Double) -> PaceSeverity {
        if offset >= 35 {
            return .severe
        }
        if offset >= 15 {
            return .critical
        }
        return .warning
    }

    static func relativeUpdatedAtLabel(for date: Date, now: Date = Date(), language: AppLanguage = .english) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        return language.relativeUpdatedAtLabel(seconds: seconds)
    }

    static func creditsText(for credits: CreditsInfo?, language: AppLanguage = .english) -> String? {
        guard let credits else { return nil }
        return language.creditsText(balance: credits.balance, hasCredits: credits.hasCredits, unlimited: credits.unlimited)
    }

    private static func rowTooltip(
        for window: LimitWindow,
        weeklyPacingMode: WeeklyPacingMode = .balanced56,
        isWeekly: Bool = false,
        language: AppLanguage = .english
    ) -> String? {
        let thresholdPercent = pacingThresholdPercent(for: window, weeklyPacingMode: weeklyPacingMode, isWeekly: isWeekly) ?? 0
        return QuotaExplanationBuilder.rowTooltip(
            for: window,
            weeklyPacingMode: weeklyPacingMode,
            isWeekly: isWeekly,
            language: language,
            thresholdPercent: thresholdPercent
        )
    }
}
