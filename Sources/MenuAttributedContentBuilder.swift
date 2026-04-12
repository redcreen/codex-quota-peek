import AppKit
import Foundation

struct MenuAttributedContentResult {
    let input: MenuUpdaterInput
    let primaryExplanationText: String?
    let secondaryExplanationText: String?
}

enum MenuAttributedContentBuilder {
    static func build(
        presentation: StatusPresentation,
        language: AppLanguage,
        showsPaceAlert: Bool,
        showsLastUpdated: Bool,
        selectedWeeklyPacingMode: WeeklyPacingMode,
        weeklyPaceExplanation: String,
        weeklyPaceInlineExplanation: String
    ) -> MenuAttributedContentResult {
        let title = styledTitle(title: language.menuQuotaTitle, subtitle: "")
        let account = styledMetaRow(
            label: presentation.accountRow?.label ?? language.accountLabel,
            value: combinedAccountLine(from: presentation)
        )

        let primaryRow = buildQuotaRow(
            row: presentation.primaryRow,
            fallbackLabel: "5 hours",
            language: language,
            showsPaceAlert: showsPaceAlert
        )

        let secondaryRow = buildQuotaRow(
            row: presentation.secondaryRow,
            fallbackLabel: "7 days",
            language: language,
            showsPaceAlert: showsPaceAlert
        )

        let secondaryExplanationText = [secondaryRow.explanationText, weeklyPaceExplanation]
            .compactMap { $0 }
            .joined(separator: "\n\n")

        let updatedAt = showsLastUpdated
            ? styledUpdatedAt(
                language: language,
                prefix: language.updatedPrefix,
                text: presentation.updatedAtText,
                source: presentation.sourceText
            )
            : nil
        let credits = presentation.creditsText.map { styledCredits($0, language: language) }
        let trend = presentation.trendSummary.map {
            styledDailyUsageChart(
                $0,
                language: language,
                weeklyPacingMode: selectedWeeklyPacingMode,
                showsPaceHighlights: showsPaceAlert
            )
        }

        return MenuAttributedContentResult(
            input: MenuUpdaterInput(
                language: language,
                presentation: presentation,
                selectedWeeklyPacingMode: selectedWeeklyPacingMode,
                showsLastUpdated: showsLastUpdated,
                title: title,
                account: account,
                primary: primaryRow.attributedTitle,
                secondary: secondaryRow.attributedTitle,
                paceNotice: styledWeeklyPaceExplanation(weeklyPaceInlineExplanation),
                updatedAt: updatedAt,
                credits: credits,
                trend: trend
            ),
            primaryExplanationText: primaryRow.explanationText,
            secondaryExplanationText: secondaryExplanationText
        )
    }

    private static func buildQuotaRow(
        row: StatusPresentation.MenuRow?,
        fallbackLabel: String,
        language: AppLanguage,
        showsPaceAlert: Bool
    ) -> (attributedTitle: NSAttributedString, explanationText: String?) {
        guard let row else {
            return (
                styledQuotaRow(
                    label: fallbackLabel,
                    language: language,
                    percent: "--",
                    reset: "--",
                    paceText: nil,
                    paceSeverity: nil,
                    paceOverrunPercent: nil,
                    usedPercent: 0,
                    paceThresholdPercent: nil,
                    markerThresholdPercent: nil,
                    displayScale: 1.0,
                    usedOnLeft: true
                ),
                nil
            )
        }

        let explanationText = showsPaceAlert ? row.tooltipText : stripPaceDetails(from: row.tooltipText)
        return (
            styledQuotaRow(
                label: row.label,
                language: language,
                percent: showsPaceAlert ? row.percentText : stripPaceMarkers(from: row.percentText),
                reset: row.resetText,
                paceText: showsPaceAlert ? row.paceText : nil,
                paceSeverity: showsPaceAlert ? row.paceSeverity : nil,
                paceOverrunPercent: showsPaceAlert ? row.paceOverrunPercent : nil,
                usedPercent: row.usedPercent,
                paceThresholdPercent: row.paceThresholdPercent,
                markerThresholdPercent: row.markerThresholdPercent,
                displayScale: 1.0,
                usedOnLeft: true
            ),
            explanationText
        )
    }

    private static func styledTitle(title: String, subtitle: String) -> NSAttributedString {
        let result = NSMutableAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ]
        )

        if !subtitle.isEmpty {
            result.append(
                NSAttributedString(
                    string: "\n\(subtitle)",
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                        .foregroundColor: NSColor.secondaryLabelColor
                    ]
                )
            )
        }

        return result
    }

    private static func styledMetaRow(label: String, value: String) -> NSAttributedString {
        let row = NSMutableAttributedString(
            string: "\(label)  ",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        row.append(
            NSAttributedString(
                string: value,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: NSColor.labelColor
                ]
            )
        )
        return row
    }

    private static func combinedAccountLine(from presentation: StatusPresentation) -> String {
        let accountValue = presentation.accountRow?.value ?? "--"
        guard let planValue = presentation.planRow?.value, planValue != "--" else {
            return accountValue
        }
        return "\(accountValue) (\(planValue))"
    }

    private static func styledQuotaRow(
        label: String,
        language: AppLanguage,
        percent: String,
        reset: String,
        paceText: String?,
        paceSeverity: StatusPresentation.PaceSeverity?,
        paceOverrunPercent: Double?,
        usedPercent: Double,
        paceThresholdPercent: Double?,
        markerThresholdPercent: Double?,
        displayScale: Double,
        usedOnLeft: Bool
    ) -> NSAttributedString {
        let barFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        let detailFont = NSFont.monospacedSystemFont(ofSize: 9.5, weight: .medium)
        let progressSlots = 28
        let titleColumnWidth = 4
        let layout = QuotaRowLayout.build(
            label: label,
            language: language,
            percentText: percent,
            reset: reset,
            markerThresholdPercent: markerThresholdPercent,
            usedOnLeft: usedOnLeft,
            displayScale: displayScale,
            slots: progressSlots
        )
        let rendered = QuotaRowTextRenderer.render(
            layout: layout,
            usedOnLeft: usedOnLeft,
            slots: progressSlots,
            titleColumnWidth: titleColumnWidth
        )
        let progressBar = styledProgressBar(
            forPercentText: percent,
            overrunPercent: paceOverrunPercent,
            usedPercent: usedPercent,
            thresholdPercent: paceThresholdPercent,
            markerThresholdPercent: markerThresholdPercent,
            paceSeverity: paceSeverity,
            displayScale: displayScale,
            usedOnLeft: usedOnLeft,
            font: barFont,
            slots: progressSlots
        )
        let header = NSMutableAttributedString()
        if let markerLine = progressBar.marker {
            header.append(
                NSAttributedString(
                    string: String(repeating: " ", count: titleColumnWidth + 1),
                    attributes: [
                        .font: barFont,
                        .foregroundColor: NSColor.clear
                    ]
                )
            )
            header.append(markerLine)
            header.append(NSAttributedString(string: "\n"))
        }
        header.append(
            NSAttributedString(
                string: layout.compactLabel.padding(toLength: titleColumnWidth, withPad: " ", startingAt: 0) + " ",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                    .foregroundColor: NSColor.labelColor
                ]
            )
        )
        header.append(progressBar.bar)
        let detailContent = layout.resetText + " " + layout.statusText
        let detailPaddingCount = max(0, rendered.detailLine.count - (titleColumnWidth + 1) - detailContent.count)
        let detail = NSMutableAttributedString(
            string: "\n" + String(repeating: " ", count: detailPaddingCount),
            attributes: [
                .font: detailFont,
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        let resetPrefix = layout.resetText + " "
        detail.append(
            NSAttributedString(
                string: resetPrefix,
                attributes: [
                    .font: detailFont,
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
            )
        )
        detail.append(
            NSAttributedString(
                string: layout.statusText,
                attributes: [
                    .font: detailFont,
                    .foregroundColor: quotaColor(for: percent)
                ]
            )
        )
        header.append(detail)
        return header
    }

    private static func styledProgressBar(
        forPercentText percentText: String,
        overrunPercent: Double?,
        usedPercent: Double,
        thresholdPercent: Double?,
        markerThresholdPercent: Double?,
        paceSeverity: StatusPresentation.PaceSeverity?,
        displayScale: Double,
        usedOnLeft: Bool,
        font: NSFont,
        slots: Int
    ) -> (marker: NSAttributedString?, bar: NSAttributedString) {
        let layout = QuotaRowLayout.build(
            label: "",
            language: .english,
            percentText: percentText,
            reset: "",
            markerThresholdPercent: markerThresholdPercent,
            usedOnLeft: usedOnLeft,
            displayScale: displayScale,
            slots: slots
        )
        let rendered = QuotaRowTextRenderer.render(
            layout: layout,
            usedOnLeft: usedOnLeft,
            slots: slots,
            titleColumnWidth: 0
        )
        let remainingColor = remainingColor(for: percentText, paceSeverity: paceSeverity)
        let usedColor = NSColor.tertiaryLabelColor
        let markerColor = NSColor.secondaryLabelColor
        let markerLine: NSAttributedString?
        if let markerString = rendered.markerLine {
            markerLine = NSAttributedString(
                string: markerString,
                attributes: [
                    .font: font,
                    .foregroundColor: markerColor
                ]
            )
        } else {
            markerLine = nil
        }

        let bar = NSMutableAttributedString()
        if usedOnLeft, layout.usedSlots > 0 {
            bar.append(
                NSAttributedString(
                    string: String(repeating: "░", count: layout.usedSlots),
                    attributes: [
                        .font: font,
                        .foregroundColor: usedColor
                    ]
                )
            )
        }
        if usedOnLeft, layout.remainingSlots > 0 {
            bar.append(
                NSAttributedString(
                    string: String(repeating: "█", count: layout.remainingSlots),
                    attributes: [
                        .font: font,
                        .foregroundColor: remainingColor
                    ]
                )
            )
        }
        if !usedOnLeft, layout.remainingSlots > 0 {
            bar.append(
                NSAttributedString(
                    string: String(repeating: "█", count: layout.remainingSlots),
                    attributes: [
                        .font: font,
                        .foregroundColor: remainingColor
                    ]
                )
            )
        }
        if !usedOnLeft, layout.usedSlots > 0 {
            bar.append(
                NSAttributedString(
                    string: String(repeating: "░", count: layout.usedSlots),
                    attributes: [
                        .font: font,
                        .foregroundColor: usedColor
                    ]
                )
            )
        }

        return (markerLine, bar)
    }

    private static func styledWeeklyPaceExplanation(_ text: String) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.paragraphSpacing = 0
        paragraph.lineSpacing = 1
        return NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: 10.5, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraph
            ]
        )
    }

    private static func stripPaceMarkers(from text: String) -> String {
        text.replacingOccurrences(of: "!", with: "")
    }

    private static func stripPaceDetails(from tooltip: String?) -> String? {
        guard let tooltip else { return nil }
        let filtered = tooltip
            .components(separatedBy: .newlines)
            .filter { line in
                !line.contains("Ahead of pace:") &&
                !line.contains("超出节奏：") &&
                !line.contains("pace:") &&
                !line.contains("Pace alert") &&
                !line.contains("节奏提醒") &&
                !line.contains("This only affects !") &&
                !line.contains("这只会影响 !")
            }
            .map(stripPaceMarkers(from:))
        return filtered.joined(separator: "\n")
    }

    private static func quotaColor(for percentText: String) -> NSColor {
        guard let percent = Int(
            percentText
                .replacingOccurrences(of: "%", with: "")
                .replacingOccurrences(of: "!", with: "")
        ) else {
            return NSColor.labelColor
        }

        if percent < 30 {
            return NSColor.systemRed
        }
        if percent < 50 {
            return NSColor.systemYellow
        }
        return NSColor.systemGreen
    }

    private static func remainingColor(for percentText: String, paceSeverity: StatusPresentation.PaceSeverity?) -> NSColor {
        guard paceSeverity != nil else {
            return NSColor.systemGreen
        }
        switch paceSeverity {
        case .warning:
            return NSColor.systemYellow
        case .critical, .severe:
            return NSColor.systemRed
        case nil:
            return NSColor.systemGreen
        }
    }

    private static func styledUpdatedAt(language: AppLanguage, prefix: String, text: String, source: String) -> NSAttributedString {
        let line = language == .english ? "\(prefix) \(text)  \(source)" : "\(text)  \(source)"
        return NSAttributedString(
            string: line,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
    }

    private static func styledDailyUsageChart(
        _ summary: CodexQuotaTrendSummary,
        language: AppLanguage,
        weeklyPacingMode: WeeklyPacingMode,
        showsPaceHighlights: Bool
    ) -> NSAttributedString {
        guard let chart = summary.chartPresentation(
            language: language,
            weeklyPacingMode: weeklyPacingMode,
            showsPaceHighlights: showsPaceHighlights
        ) else {
            return NSAttributedString(string: "")
        }

        let lines = dailyUsageChartLines(for: chart)
        let result = NSMutableAttributedString()
        for (index, line) in lines.enumerated() {
            if index == 0 {
                result.append(
                    NSAttributedString(
                        string: line,
                        attributes: [
                            .font: NSFont.systemFont(ofSize: 11.5, weight: .semibold),
                            .foregroundColor: NSColor.secondaryLabelColor
                        ]
                    )
                )
            } else if index <= chart.axisThresholds.count {
                let threshold = chart.axisThresholds[index - 1]
                result.append(styledDailyUsageChartRow(for: chart, threshold: threshold))
            } else if index == chart.axisThresholds.count + 1 {
                result.append(styledDailyUsageChartAxis(for: chart))
            } else {
                result.append(styledDailyUsageChartFooter(for: chart))
            }
            if index < lines.count - 1 {
                result.append(NSAttributedString(string: "\n"))
            }
        }
        return result
    }

    private static func dailyUsageChartLines(for chart: CodexQuotaTrendSummary.ChartPresentation) -> [String] {
        let rows = chart.axisThresholds.map { threshold -> String in
            let bars = chart.days.map { day -> String in
                let glyph = day.hours >= threshold ? "██" : "  "
                return glyph.padding(toLength: chart.columnWidth, withPad: " ", startingAt: 0)
            }.joined()
            return String(format: "%2dh │ %@", threshold, bars)
        }
        let axis = "    └" + chart.days.enumerated().map { index, _ in
            index == chart.days.count - 1 ? "───" : "──┬"
        }.joined()
        let footer = "    " + chart.days.map { day in
            day.label.padding(toLength: chart.columnWidth, withPad: " ", startingAt: 0)
        }.joined()
        return [chart.title] + rows + [axis, footer]
    }

    private static func styledDailyUsageChartRow(for chart: CodexQuotaTrendSummary.ChartPresentation, threshold: Int) -> NSAttributedString {
        let axisFont = NSFont.monospacedSystemFont(ofSize: 11.5, weight: .medium)
        let row = NSMutableAttributedString(
            string: String(format: "%2dh ┤ ", threshold),
            attributes: [
                .font: axisFont,
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )

        for day in chart.days {
            let isFilled = day.hours >= threshold
            let glyph = isFilled ? "██" : "  "
            let paddedGlyph = glyph.padding(toLength: chart.columnWidth, withPad: " ", startingAt: 0)
            let color: NSColor
            switch DailyUsageChartStylePolicy.barTone(
                isFilled: isFilled,
                isAheadOfPace: day.isAheadOfPace,
                isFuture: day.isFuture
            ) {
            case .muted:
                color = NSColor.tertiaryLabelColor
            case .alert:
                color = NSColor.systemRed
            case .normal:
                color = NSColor.systemGreen
            }
            row.append(
                NSAttributedString(
                    string: paddedGlyph,
                    attributes: [
                        .font: axisFont,
                        .foregroundColor: color
                    ]
                )
            )
        }

        return row
    }

    private static func styledDailyUsageChartFooter(for chart: CodexQuotaTrendSummary.ChartPresentation) -> NSAttributedString {
        let font = NSFont.monospacedSystemFont(ofSize: 11.5, weight: .medium)
        let footer = NSMutableAttributedString(
            string: "     ",
            attributes: [
                .font: font,
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )

        for day in chart.days {
            let color: NSColor
            switch DailyUsageChartStylePolicy.footerTone(
                isAheadOfPace: day.isAheadOfPace,
                isFuture: day.isFuture
            ) {
            case .muted:
                color = NSColor.tertiaryLabelColor
            case .alert:
                color = NSColor.systemRed
            case .normal:
                color = NSColor.secondaryLabelColor
            }
            footer.append(
                NSAttributedString(
                    string: day.label.padding(toLength: chart.columnWidth, withPad: " ", startingAt: 0),
                    attributes: [
                        .font: font,
                        .foregroundColor: color
                    ]
                )
            )
        }
        return footer
    }

    private static func styledDailyUsageChartAxis(for chart: CodexQuotaTrendSummary.ChartPresentation) -> NSAttributedString {
        let font = NSFont.monospacedSystemFont(ofSize: 11.5, weight: .medium)
        let axis = NSMutableAttributedString(
            string: "     └",
            attributes: [
                .font: font,
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )

        for (index, _) in chart.days.enumerated() {
            axis.append(
                NSAttributedString(
                    string: index == chart.days.count - 1 ? "───" : "──┬",
                    attributes: [
                        .font: font,
                        .foregroundColor: NSColor.secondaryLabelColor
                    ]
                )
            )
        }

        return axis
    }

    private static func styledCredits(_ text: String, language: AppLanguage) -> NSAttributedString {
        let row = NSMutableAttributedString(
            string: "\(language.creditsLabel): ",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        row.append(
            NSAttributedString(
                string: text,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                    .foregroundColor: NSColor.labelColor
                ]
            )
        )
        return row
    }
}
