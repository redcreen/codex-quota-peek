import AppKit

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)

image.lockFocus()

let shadowRect = NSRect(x: 168, y: 190, width: 688, height: 688)
let shadowPath = NSBezierPath(ovalIn: shadowRect)
NSColor(calibratedWhite: 0.0, alpha: 0.18).setFill()
shadowPath.fill()

let ringRect = NSRect(x: 196, y: 176, width: 632, height: 632)
let ringPath = NSBezierPath()
ringPath.appendArc(withCenter: NSPoint(x: ringRect.midX, y: ringRect.midY), radius: 256, startAngle: 215, endAngle: -35, clockwise: false)
ringPath.lineWidth = 58
NSColor(calibratedWhite: 0.95, alpha: 1.0).setStroke()
ringPath.stroke()

let needle = NSBezierPath()
needle.move(to: NSPoint(x: 512, y: 490))
needle.line(to: NSPoint(x: 720, y: 674))
needle.lineWidth = 46
needle.lineCapStyle = .round
NSColor(calibratedWhite: 0.95, alpha: 1.0).setStroke()
needle.stroke()

let hubRect = NSRect(x: 450, y: 430, width: 124, height: 124)
let hubPath = NSBezierPath(ovalIn: hubRect)
NSColor(calibratedWhite: 0.98, alpha: 1.0).setFill()
hubPath.fill()

let qCircleRect = NSRect(x: 292, y: 270, width: 440, height: 440)
let qCirclePath = NSBezierPath(ovalIn: qCircleRect)
qCirclePath.lineWidth = 48
NSColor(calibratedWhite: 0.98, alpha: 1.0).setStroke()
qCirclePath.stroke()

let qTail = NSBezierPath()
qTail.move(to: NSPoint(x: 636, y: 348))
qTail.line(to: NSPoint(x: 748, y: 236))
qTail.lineWidth = 40
qTail.lineCapStyle = .round
NSColor(calibratedWhite: 0.98, alpha: 1.0).setStroke()
qTail.stroke()

let innerDiskRect = NSRect(x: 382, y: 360, width: 260, height: 260)
let innerDiskPath = NSBezierPath(ovalIn: innerDiskRect)
NSColor(calibratedWhite: 0.08, alpha: 0.94).setFill()
innerDiskPath.fill()

let quotaText = "Q"
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 196, weight: .black),
    .foregroundColor: NSColor(calibratedWhite: 0.98, alpha: 1.0),
    .paragraphStyle: paragraph
]
quotaText.draw(in: NSRect(x: 0, y: 338, width: 1024, height: 220), withAttributes: attributes)

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
