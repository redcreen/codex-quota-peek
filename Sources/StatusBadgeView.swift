import AppKit

final class StatusBadgeView: NSView {
    var line1: String = "H --" {
        didSet { invalidateLayout() }
    }

    var line2: String = "W --" {
        didSet { invalidateLayout() }
    }

    override var intrinsicContentSize: NSSize {
        let line1Size = line1.size(withAttributes: lineAttributes)
        let line2Size = line2.size(withAttributes: lineAttributes)
        let textWidth = ceil(max(line1Size.width, line2Size.width))
        let width = iconSize + iconSpacing + textWidth + padding * 2
        return NSSize(width: max(50, width), height: 20)
    }

    private let padding: CGFloat = 4
    private let iconSize: CGFloat = 18
    private let iconSpacing: CGFloat = 6

    private let lineAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .semibold),
        .foregroundColor: NSColor.white
    ]

    override func draw(_ dirtyRect: NSRect) {
        drawIcon()
        drawText(line1, yOffset: 9.4)
        drawText(line2, yOffset: 1.2)
    }

    private func drawIcon() {
        guard let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
              let icon = NSImage(contentsOf: iconURL) else {
            return
        }

        let y = round((bounds.height - iconSize) / 2)
        icon.draw(in: NSRect(x: padding, y: y, width: iconSize, height: iconSize))
    }

    private func drawText(_ text: String, yOffset: CGFloat) {
        let point = NSPoint(x: round(padding + iconSize + iconSpacing), y: yOffset)
        text.draw(at: point, withAttributes: lineAttributes)
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
