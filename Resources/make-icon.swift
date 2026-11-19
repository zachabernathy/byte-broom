// Regenerates AppIcon.icns from AppIcon-source.png (artwork on a white background).
// Run from Resources: swift make-icon.swift
import AppKit

let src = NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: "AppIcon-source.png")))!

// Find the artwork's tile: the bounding box of pixels that aren't near-white.
var minX = src.pixelsWide, minY = src.pixelsHigh, maxX = 0, maxY = 0
for y in 0..<src.pixelsHigh {
    for x in 0..<src.pixelsWide {
        guard let c = src.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
        if c.redComponent + c.greenComponent + c.blueComponent < 2.7 {
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        }
    }
}
// Inset a little so the tile's own soft edge and shadow don't show past our mask.
let inset = Double(maxX - minX) * 0.03
let crop = NSRect(x: Double(minX) + inset, y: Double(src.pixelsHigh - 1 - maxY) + inset,
                  width: Double(maxX - minX) - 2 * inset, height: Double(maxY - minY) - 2 * inset)
let art = NSImage(size: NSSize(width: src.pixelsWide, height: src.pixelsHigh))
art.addRepresentation(src)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current!.imageInterpolation = .high
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185).addClip()
art.draw(in: tile, from: crop, operation: .copy, fraction: 1)
NSGraphicsContext.restoreGraphicsState()

let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: tmp)
try! FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
let master = tmp.appendingPathComponent("icon_512x512@2x.png")
try! rep.representation(using: .png, properties: [:])!.write(to: master)

func run(_ args: [String]) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    p.arguments = args
    p.standardOutput = FileHandle.nullDevice
    try! p.run()
    p.waitUntilExit()
    precondition(p.terminationStatus == 0, "failed: \(args)")
}

for px in [16, 32, 128, 256, 512] {
    for scale in [1, 2] where !(px == 512 && scale == 2) {
        let name = scale == 1 ? "icon_\(px)x\(px).png" : "icon_\(px)x\(px)@2x.png"
        let out = tmp.appendingPathComponent(name).path
        run(["sips", "-z", "\(px * scale)", "\(px * scale)", master.path, "--out", out])
    }
}
run(["iconutil", "-c", "icns", tmp.path, "-o", "AppIcon.icns"])
try? FileManager.default.removeItem(at: tmp)
print("Wrote AppIcon.icns")
