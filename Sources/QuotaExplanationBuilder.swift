import Foundation

enum QuotaExplanationBuilder {
    static func rowTooltip(
        for window: LimitWindow,
        weeklyPacingMode: WeeklyPacingMode = .balanced56,
        isWeekly: Bool = false,
        language: AppLanguage = .english,
        thresholdPercent: Double
    ) -> String? {
        let totalHours = totalReferenceHours(for: window, weeklyPacingMode: weeklyPacingMode, isWeekly: isWeekly)
        guard totalHours > 0 else { return nil }

        let usedHours = totalHours * (window.usedPercent / 100.0)
        let normalElapsedHours = totalHours * (thresholdPercent / 100.0)
        let remainingHours = max(0, totalHours - usedHours)
        let aheadHours = max(0, usedHours - normalElapsedHours)

        var parts: [String] = []
        if isWeekly {
            parts.append(language == .english ? "Based on \(weeklyPacingMode.title)" : "按 \(weeklyPacingMode.title) 计算")
        }
        parts.append(language == .english ? "▼ marks the normal progress position on the bar." : "▼ 表示进度条上的正常进度位置。")
        parts.append(
            language == .english
                ? "Total: \(formattedDuration(hours: totalHours, language: language)) (100%)"
                : "总量：\(formattedDuration(hours: totalHours, language: language))（100%）"
        )
        parts.append(
            language == .english
                ? "Normal elapsed: \(formattedDuration(hours: normalElapsedHours, language: language)) (\(percentString(thresholdPercent)))"
                : "正常经过：\(formattedDuration(hours: normalElapsedHours, language: language))（\(percentString(thresholdPercent))）"
        )
        parts.append(
            language == .english
                ? "Used: \(formattedDuration(hours: usedHours, language: language)) (\(percentString(window.usedPercent)))"
                : "已用：\(formattedDuration(hours: usedHours, language: language))（\(percentString(window.usedPercent))）"
        )
        parts.append(
            language == .english
                ? "Remaining: \(formattedDuration(hours: remainingHours, language: language)) (\(percentString(Double(window.remainingPercent))))"
                : "剩余：\(formattedDuration(hours: remainingHours, language: language))（\(percentString(Double(window.remainingPercent)))）"
        )
        if aheadHours > 0 {
            parts.append(
                language == .english
                    ? "Ahead of pace: \(formattedDuration(hours: aheadHours, language: language)) (\(percentString(max(0, window.usedPercent - thresholdPercent))))"
                    : "超出节奏：\(formattedDuration(hours: aheadHours, language: language))（\(percentString(max(0, window.usedPercent - thresholdPercent)))）"
            )
        }
        return parts.joined(separator: "\n")
    }

    static func totalReferenceHours(
        for window: LimitWindow,
        weeklyPacingMode: WeeklyPacingMode,
        isWeekly: Bool
    ) -> Double {
        if isWeekly {
            return Double(weeklyPacingMode.weeklyHours)
        }
        guard let minutes = window.windowMinutes else { return 0 }
        return Double(minutes) / 60.0
    }

    static func formattedDuration(hours: Double, language: AppLanguage) -> String {
        let clampedHours = max(0, hours)
        if clampedHours == 0 {
            return language == .english ? "0m" : "0分钟"
        }
        if clampedHours < 1 {
            let minutes = max(1, Int((clampedHours * 60.0).rounded()))
            return language == .english ? "\(minutes)m" : "\(minutes)分钟"
        }
        if clampedHours < 10 {
            let decimalHours = (clampedHours * 10.0).rounded() / 10.0
            let formatted = decimalHours == floor(decimalHours)
                ? String(format: "%.0f", decimalHours)
                : String(format: "%.1f", decimalHours)
            return language == .english ? "\(formatted)h" : "\(formatted)小时"
        }
        let roundedHours = max(1, Int(clampedHours.rounded()))
        return language == .english ? "\(roundedHours)h" : "\(roundedHours)小时"
    }

    static func percentString(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }
}
