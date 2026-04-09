import Foundation

struct QuotaRowTextRenderer {
    struct RenderedRow {
        let markerLine: String?
        let barBody: String
        let detailLine: String
    }

    static func render(
        layout: QuotaRowLayout,
        usedOnLeft: Bool,
        slots: Int = 28,
        titleColumnWidth: Int = 4,
        usedGlyph: Character = "░",
        remainingGlyph: Character = "█"
    ) -> RenderedRow {
        let usedSegment = String(repeating: String(usedGlyph), count: layout.usedSlots)
        let remainingSegment = String(repeating: String(remainingGlyph), count: layout.remainingSlots)
        let barBody = usedOnLeft
            ? usedSegment + remainingSegment
            : remainingSegment + usedSegment

        let markerLine: String?
        if let markerIndex = layout.markerIndex {
            let clamped = max(0, min(slots - 1, markerIndex))
            markerLine = String(repeating: " ", count: clamped) + "▼"
        } else {
            markerLine = nil
        }

        let detailContent = layout.resetText + " " + layout.statusText
        let detailPadding = max(0, slots - detailContent.count)
        let detailLine = String(repeating: " ", count: titleColumnWidth + 1 + detailPadding) + detailContent

        return RenderedRow(
            markerLine: markerLine,
            barBody: barBody,
            detailLine: detailLine
        )
    }
}
