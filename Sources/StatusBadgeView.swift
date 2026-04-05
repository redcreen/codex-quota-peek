import AppKit

final class StatusBadgeView: NSView {
    var showsColors: Bool = true {
        didSet { invalidateLayout() }
    }

    var line1: String = "H --" {
        didSet { invalidateLayout() }
    }

    var line2: String = "W --" {
        didSet { invalidateLayout() }
    }

    override var intrinsicContentSize: NSSize {
        let alignedWidth = max(alignedTextWidth(for: line1), alignedTextWidth(for: line2))
        let width = iconSize + iconSpacing + alignedWidth + padding * 2
        return NSSize(width: max(54, width), height: 22)
    }

    private let padding: CGFloat = 1
    private let iconSize: CGFloat = 22
    private let iconSpacing: CGFloat = 5
    private let prefixColumnWidth: CGFloat = 9
    private let iconCropInsetRatio: CGFloat = 0.16

    private let prefixAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .semibold),
        .foregroundColor: NSColor.white
    ]

    override func draw(_ dirtyRect: NSRect) {
        drawIcon()
        drawAlignedText(line1, yOffset: 10.4)
        drawAlignedText(line2, yOffset: 2.0)
    }

    private func drawIcon() {
        guard let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
              let icon = NSImage(contentsOf: iconURL) else {
            return
        }

        let sourceInsetX = icon.size.width * iconCropInsetRatio
        let sourceInsetY = icon.size.height * iconCropInsetRatio
        let sourceRect = NSRect(
            x: sourceInsetX,
            y: sourceInsetY,
            width: icon.size.width - sourceInsetX * 2,
            height: icon.size.height - sourceInsetY * 2
        )
        let destinationRect = NSRect(x: padding, y: 0, width: iconSize, height: iconSize)

        icon.draw(
            in: destinationRect,
            from: sourceRect,
            operation: .sourceOver,
            fraction: 1.0
        )
    }

    private func drawAlignedText(_ text: String, yOffset: CGFloat) {
        let baseX = round(padding + iconSize + iconSpacing)
        let parts = text.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        let prefix = parts.first.map(String.init) ?? text
        let suffix = parts.count > 1 ? String(parts[1]) : ""
        let components = splitPercentComponents(suffix)

        prefix.draw(at: NSPoint(x: baseX, y: yOffset), withAttributes: prefixAttributes)
        components.value.draw(
            at: NSPoint(x: baseX + prefixColumnWidth, y: yOffset),
            withAttributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .semibold),
                .foregroundColor: quotaColor(for: components.value)
            ]
        )

        guard !components.marker.isEmpty else { return }

        let markerX = baseX + prefixColumnWidth + ceil(components.value.size(withAttributes: prefixAttributes).width)
        components.marker.draw(
            at: NSPoint(x: markerX, y: yOffset),
            withAttributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .bold),
                .foregroundColor: paceColor(for: components.marker)
            ]
        )
    }

    private func alignedTextWidth(for text: String) -> CGFloat {
        let parts = text.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        let suffix = parts.count > 1 ? String(parts[1]) : ""
        let suffixWidth = ceil(suffix.size(withAttributes: prefixAttributes).width)
        return prefixColumnWidth + suffixWidth
    }

    private func splitPercentComponents(_ text: String) -> (value: String, marker: String) {
        let marker = text.filter { $0 == "!" }
        let value = text.replacingOccurrences(of: "!", with: "")
        return (value, marker)
    }

    private func quotaColor(for text: String) -> NSColor {
        guard showsColors else { return .white }
        guard let percent = Int(
            text
                .replacingOccurrences(of: "%", with: "")
                .replacingOccurrences(of: "!", with: "")
        ) else {
            return .white
        }

        if percent < 30 {
            return NSColor(calibratedRed: 1.0, green: 0.34, blue: 0.32, alpha: 1.0)
        }
        if percent < 50 {
            return NSColor(calibratedRed: 0.98, green: 0.83, blue: 0.28, alpha: 1.0)
        }
        return NSColor(calibratedRed: 0.43, green: 0.93, blue: 0.58, alpha: 1.0)
    }

    private func paceColor(for marker: String) -> NSColor {
        guard showsColors else { return .white }
        return marker.count >= 2
            ? NSColor(calibratedRed: 1.0, green: 0.34, blue: 0.32, alpha: 1.0)
            : NSColor(calibratedRed: 0.98, green: 0.83, blue: 0.28, alpha: 1.0)
    }

    private func invalidateLayout() {
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    func renderedImage() -> NSImage {
        let targetSize = intrinsicContentSize
        frame = NSRect(origin: .zero, size: targetSize)
        layoutSubtreeIfNeeded()

        let image = NSImage(size: targetSize)
        image.lockFocus()
        draw(bounds)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
