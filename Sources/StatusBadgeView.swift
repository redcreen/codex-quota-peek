import AppKit

final class StatusBadgeView: NSView {
    var line1: String = "P --" {
        didSet { invalidateLayout() }
    }

    var line2: String = "W --" {
        didSet { invalidateLayout() }
    }

    override var intrinsicContentSize: NSSize {
        let line1Size = line1.size(withAttributes: lineAttributes)
        let line2Size = line2.size(withAttributes: lineAttributes)
        let width = ceil(max(line1Size.width, line2Size.width) + padding * 2)
        return NSSize(width: max(54, width), height: 24)
    }

    private let padding: CGFloat = 8

    private let lineAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
        .foregroundColor: NSColor.white
    ]

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)

        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.32, green: 0.69, blue: 0.93, alpha: 1.0),
            NSColor(calibratedRed: 0.18, green: 0.53, blue: 0.83, alpha: 1.0)
        ])
        gradient?.draw(in: path, angle: -90)

        drawText(line1, yOffset: 12.5)
        drawText(line2, yOffset: 2.0)
    }

    private func drawText(_ text: String, yOffset: CGFloat) {
        let size = text.size(withAttributes: lineAttributes)
        let point = NSPoint(x: round((bounds.width - size.width) / 2), y: yOffset)
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
