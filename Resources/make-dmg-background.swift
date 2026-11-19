// Regenerates dmg-background.tiff, the DMG window backdrop (1x + 2x in one file).
// Run from Resources: swift make-dmg-background.swift
// Icon centers in scripts/make-dmg.sh must match appX, appsX and iconY below.
import AppKit

let width = 660.0, height = 400.0
let appX = 165.0, appsX = 495.0, iconY = 180.0  // Finder coordinates: origin at top-left.

func render(scale: Double) -> URL {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let bounds = NSRect(x: 0, y: 0, width: width, height: height)

    NSGradient(colors: [NSColor(red: 1.0, green: 0.97, blue: 0.93, alpha: 1),
                        NSColor(red: 1.0, green: 0.88, blue: 0.80, alpha: 1)])!.draw(in: bounds, angle: -90)

    let orange = NSColor(red: 1.0, green: 0.45, blue: 0.10, alpha: 1)
    let pink = NSColor(red: 1.0, green: 0.20, blue: 0.55, alpha: 1)
    let y = height - iconY
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: appX + 85, y: y))
    arrow.line(to: NSPoint(x: appsX - 105, y: y))
    arrow.lineWidth = 8
    arrow.lineCapStyle = .round
    let head = NSBezierPath()
    head.move(to: NSPoint(x: appsX - 85, y: y))
    head.line(to: NSPoint(x: appsX - 115, y: y + 20))
    head.line(to: NSPoint(x: appsX - 115, y: y - 20))
    head.close()
    NSGraphicsContext.saveGraphicsState()
    let glow = NSShadow()
    glow.shadowColor = pink.withAlphaComponent(0.6)
    glow.shadowBlurRadius = 10
    glow.set()
    orange.setStroke(); orange.setFill()
    arrow.stroke(); head.fill()
    NSGraphicsContext.restoreGraphicsState()

    let text = "Drag Byte Broom to Applications" as NSString
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
        .foregroundColor: NSColor(red: 0.30, green: 0.18, blue: 0.12, alpha: 1),
    ]
    let size = text.size(withAttributes: attrs)
    text.draw(at: NSPoint(x: (width - size.width) / 2, y: 70), withAttributes: attrs)
    NSGraphicsContext.restoreGraphicsState()

    let url = FileManager.default.temporaryDirectory.appendingPathComponent("dmg-bg-\(Int(scale))x.png")
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
    return url
}

let one = render(scale: 1), two = render(scale: 2)
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/tiffutil")
p.arguments = ["-cathidpicheck", one.path, two.path, "-out", "dmg-background.tiff"]
try! p.run()
p.waitUntilExit()
precondition(p.terminationStatus == 0, "tiffutil failed")
try? FileManager.default.removeItem(at: one)
try? FileManager.default.removeItem(at: two)
print("Wrote dmg-background.tiff")
