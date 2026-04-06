import Foundation

struct MenuContractSnapshot {
    let title: String
    let accountLine: String
    let primaryLabel: String
    let secondaryLabel: String
    let weeklySelectorTitle: String
    let weeklyOptions: [String]
    let weeklyExplanation: String
    let creditsLine: String?
    let updatedLine: String?
    let actionTitles: [String]
}

enum MenuContractBuilder {
    static func build(
        presentation: StatusPresentation,
        language: AppLanguage,
        weeklyPacingMode: WeeklyPacingMode,
        showsLastUpdated: Bool
    ) -> MenuContractSnapshot {
        let accountValue = presentation.accountRow?.value ?? "--"
        let planValue = presentation.planRow?.value
        let combinedAccountLine: String
        if let planValue, planValue != "--" {
            combinedAccountLine = "\(presentation.accountRow?.label ?? language.accountLabel) \(accountValue) (\(planValue))"
        } else {
            combinedAccountLine = "\(presentation.accountRow?.label ?? language.accountLabel) \(accountValue)"
        }

        let updatedLine: String?
        if showsLastUpdated {
            updatedLine = "\(presentation.updatedAtText) \(presentation.sourceText)"
        } else {
            updatedLine = nil
        }

        let actionTitles = [
            language.refreshNowTitle,
            language.switchAccountTitle,
            language.usageDashboardTitle,
            language.statusPageTitle,
            language.copyDetailsTitle,
            language.openCodexFolderTitle,
            language.revealLogsDatabaseTitle,
            language.preferencesMenuTitle,
            language.aboutTitle,
            language.quitTitle
        ]

        return MenuContractSnapshot(
            title: language.menuQuotaTitle,
            accountLine: combinedAccountLine,
            primaryLabel: compactQuotaLabel(for: presentation.primaryRow?.label, language: language, fallback: language.windowLabel(for: 300)),
            secondaryLabel: compactQuotaLabel(for: presentation.secondaryRow?.label, language: language, fallback: language.windowLabel(for: 10080)),
            weeklySelectorTitle: language == .english ? "Weekly work hours" : "每周工作时长",
            weeklyOptions: WeeklyPacingMode.allCases.map { "\($0.weeklyHours)h" },
            weeklyExplanation: QuotaDisplayPolicy.weeklyPaceInlineExplanation(for: weeklyPacingMode, language: language),
            creditsLine: presentation.creditsText.map { "\(language.creditsLabel): \($0)" },
            updatedLine: updatedLine,
            actionTitles: actionTitles
        )
    }

    private static func compactQuotaLabel(for raw: String?, language: AppLanguage, fallback: String) -> String {
        let label = raw ?? fallback
        if language == .english {
            if label == "5 hours" { return "5h" }
            if label == "7 days" { return "7d" }
        } else {
            if label == "5 小时" { return "5h" }
            if label == "7 天" { return "7d" }
        }
        return label
    }
}
