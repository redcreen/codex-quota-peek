import AppKit

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)

image.lockFocus()

let rect = NSRect(origin: .zero, size: size)
let backgroundPath = NSBezierPath(roundedRect: rect.insetBy(dx: 36, dy: 36), xRadius: 220, yRadius: 220)
let backgroundGradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.08, green: 0.47, blue: 0.89, alpha: 1.0),
    NSColor(calibratedRed: 0.03, green: 0.22, blue: 0.52, alpha: 1.0)
])
backgroundGradient?.draw(in: backgroundPath, angle: -90)

let glowRect = NSRect(x: 130, y: 560, width: 760, height: 270)
let glowPath = NSBezierPath(roundedRect: glowRect, xRadius: 140, yRadius: 140)
NSColor(calibratedWhite: 1.0, alpha: 0.10).setFill()
glowPath.fill()

let ringRect = NSRect(x: 228, y: 208, width: 568, height: 568)
let ringPath = NSBezierPath()
ringPath.appendArc(withCenter: NSPoint(x: ringRect.midX, y: ringRect.midY), radius: 230, startAngle: 215, endAngle: -35, clockwise: false)
ringPath.lineWidth = 54
NSColor.white.withAlphaComponent(0.95).setStroke()
ringPath.stroke()

let needle = NSBezierPath()
needle.move(to: NSPoint(x: 512, y: 492))
needle.line(to: NSPoint(x: 690, y: 650))
needle.lineWidth = 42
needle.lineCapStyle = .round
NSColor.white.setStroke()
needle.stroke()

let hubRect = NSRect(x: 458, y: 438, width: 108, height: 108)
let hubPath = NSBezierPath(ovalIn: hubRect)
NSColor.white.setFill()
hubPath.fill()

let quotaText = "CQ"
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 220, weight: .black),
    .foregroundColor: NSColor.white,
    .paragraphStyle: paragraph
]
quotaText.draw(in: NSRect(x: 0, y: 70, width: 1024, height: 250), withAttributes: attributes)

image.unlockFocus()

guard
    let tiffData = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiffData),
    let pngData = bitmap.representation(using: .png, properties: [:])
else {
    fputs("Failed to render icon\n", stderr)
    exit(1)
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/AppIcon.png"
let outputURL = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try pngData.write(to: outputURL)
print("Generated icon at: \(outputPath)")
