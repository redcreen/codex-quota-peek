import Foundation

struct QuotaRowLayout {
    let compactLabel: String
    let percentValue: String
    let percentMarker: String
    let statusText: String
    let resetText: String
    let detailText: String
    let markerPercent: Double?
    let markerIndex: Int?
    let activeSlots: Int
    let remainingSlots: Int
    let usedSlots: Int

    static func build(
        label: String,
        language: AppLanguage,
        percentText: String,
        reset: String,
        markerThresholdPercent: Double?,
        usedOnLeft: Bool,
        displayScale: Double = 1.0,
        slots: Int = 28
    ) -> QuotaRowLayout {
        let compactLabel = compactQuotaLabel(for: label, language: language)
        let (percentValue, percentMarker) = splitPercentComponents(percentText)
        let statusText = percentMarker.isEmpty
            ? "\(language.leftLabel) \(percentValue)"
            : "\(language.leftLabel) \(percentValue) \(percentMarker)"
        let resetText = "\(language.resetsLabel) \(reset)"
        let detailText = "\(resetText) \(statusText)"

        let activeSlots = max(1, min(slots, Int((Double(slots) * displayScale).rounded())))
        let segments = QuotaDisplayPolicy.progressSegments(
            forPercentText: percentText,
            usedOnLeft: usedOnLeft,
            slots: slots
        )

        let markerPercent = markerThresholdPercent.map { max(0, min(100, $0)) }
        let markerIndex = markerPercent.map { percent -> Int in
            let visualPercent = usedOnLeft ? percent : (100.0 - percent)
            return max(0, min(slots, Int((visualPercent / 100.0 * Double(slots)).rounded())))
        }

        return QuotaRowLayout(
            compactLabel: compactLabel,
            percentValue: percentValue,
            percentMarker: percentMarker,
            statusText: statusText,
            resetText: resetText,
            detailText: detailText,
            markerPercent: markerPercent,
            markerIndex: markerIndex,
            activeSlots: activeSlots,
            remainingSlots: segments.remaining,
            usedSlots: segments.used
        )
    }

    private static func compactQuotaLabel(for label: String, language: AppLanguage) -> String {
        if language == .english {
            if label == "5 hours" { return "5h" }
            if label == "7 days" { return "7d" }
        } else {
            if label == "5 小时" { return "5h" }
            if label == "7 天" { return "7d" }
        }
        return label
    }

    private static func splitPercentComponents(_ percentText: String) -> (String, String) {
        let marker = percentText.filter { $0 == "!" }
        let value = percentText.replacingOccurrences(of: "!", with: "")
        return (value, marker)
    }
}
