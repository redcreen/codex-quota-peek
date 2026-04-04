import AppKit

final class StatusBadgeView: NSView {
    var line1: String = "H --" {
        didSet { invalidateLayout() }
    }

    var line2: String = "W --" {
        didSet { invalidateLayout() }
    }

    override var intrinsicContentSize: NSSize {
        let alignedWidth = max(alignedTextWidth(for: line1), alignedTextWidth(for: line2))
        let width = iconSize + iconSpacing + alignedWidth + padding * 2
        return NSSize(width: max(52, width), height: 20)
    }

    private let padding: CGFloat = 2
    private let iconSize: CGFloat = 20
    private let iconSpacing: CGFloat = 6
    private let prefixColumnWidth: CGFloat = 9

    private let lineAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .semibold),
        .foregroundColor: NSColor.white
    ]

    override func draw(_ dirtyRect: NSRect) {
        drawIcon()
        drawAlignedText(line1, yOffset: 9.3)
        drawAlignedText(line2, yOffset: 1.1)
    }

    private func drawIcon() {
        guard let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
              let icon = NSImage(contentsOf: iconURL) else {
            return
        }

        icon.draw(in: NSRect(x: padding, y: 0, width: iconSize, height: iconSize))
    }

    private func drawAlignedText(_ text: String, yOffset: CGFloat) {
        let baseX = round(padding + iconSize + iconSpacing)
        let parts = text.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        let prefix = parts.first.map(String.init) ?? text
        let suffix = parts.count > 1 ? String(parts[1]) : ""

        prefix.draw(at: NSPoint(x: baseX, y: yOffset), withAttributes: lineAttributes)
        suffix.draw(at: NSPoint(x: baseX + prefixColumnWidth, y: yOffset), withAttributes: lineAttributes)
    }

    private func alignedTextWidth(for text: String) -> CGFloat {
        let parts = text.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        let suffix = parts.count > 1 ? String(parts[1]) : ""
        let suffixWidth = ceil(suffix.size(withAttributes: lineAttributes).width)
        return prefixColumnWidth + suffixWidth
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
