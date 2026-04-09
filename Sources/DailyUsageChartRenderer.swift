import Foundation

enum DailyUsageChartRenderer {
    static func render(_ chart: CodexQuotaTrendSummary.ChartPresentation) -> String {
        let rows = chart.axisThresholds.map { threshold -> String in
            let bars = chart.days.map { day -> String in
                let glyph = day.hours >= threshold ? "██" : "  "
                return glyph.padding(toLength: chart.columnWidth, withPad: " ", startingAt: 0)
            }.joined()
            return String(format: "%2dh ┤ %@", threshold, bars)
        }

        let axis = "     └" + chart.days.enumerated().map { index, _ in
            index == chart.days.count - 1 ? "───" : "──┬"
        }.joined()
        let footer = "     " + chart.days.map { day in
            day.label.padding(toLength: chart.columnWidth, withPad: " ", startingAt: 0)
        }.joined()

        return ([chart.title] + rows + [axis, footer]).joined(separator: "\n")
    }
}
