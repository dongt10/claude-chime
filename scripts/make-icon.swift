#!/usr/bin/env swift
// Generates Resources/AppIcon.icns from a bell emoji on a warm gradient.
// Re-run after editing this file: `swift scripts/make-icon.swift`
//
// We render straight into an NSBitmapImageRep via NSGraphicsContext —
// NSImage.lockFocus() needs an active NSApplication context which a swift
// script doesn't have, so it crashes on the unlock.

import Cocoa

struct IconSlot {
    let logicalSize: Int
    let scale: Int
    var pixelSize: Int { logicalSize * scale }
    var fileName: String {
        scale == 1 ? "icon_\(logicalSize)x\(logicalSize).png"
                   : "icon_\(logicalSize)x\(logicalSize)@2x.png"
    }
}

let slots: [IconSlot] = [
    .init(logicalSize: 16,  scale: 1),
    .init(logicalSize: 16,  scale: 2),
    .init(logicalSize: 32,  scale: 1),
    .init(logicalSize: 32,  scale: 2),
    .init(logicalSize: 128, scale: 1),
    .init(logicalSize: 128, scale: 2),
    .init(logicalSize: 256, scale: 1),
    .init(logicalSize: 256, scale: 2),
    .init(logicalSize: 512, scale: 1),
    .init(logicalSize: 512, scale: 2),  // 1024px
]

func renderIcon(pixels: Int) -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Could not allocate bitmap of size \(pixels)px")
    }

    let side = CGFloat(pixels)
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    // Squircle background.
    let bgRect = NSRect(x: 0, y: 0, width: side, height: side)
    let radius = side * 0.225
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: radius, yRadius: radius)

    NSGraphicsContext.saveGraphicsState()
    bgPath.addClip()  // keeps emoji shadow within the squircle

    // Warm vertical gradient.
    let gradient = NSGradient(colors: [
        NSColor(red: 1.00, green: 0.62, blue: 0.20, alpha: 1.0),  // amber top
        NSColor(red: 0.96, green: 0.30, blue: 0.18, alpha: 1.0)   // red-orange bottom
    ])!
    gradient.draw(in: bgPath, angle: -90)

    // Soft inner highlight along the rim.
    let highlightPath = NSBezierPath(
        roundedRect: bgRect.insetBy(dx: 1, dy: 1),
        xRadius: max(radius - 1, 0),
        yRadius: max(radius - 1, 0)
    )
    NSColor.white.withAlphaComponent(0.14).setStroke()
    highlightPath.lineWidth = max(side * 0.005, 1)
    highlightPath.stroke()

    // Bell emoji, centered with a slight downward bias for optical balance,
    // with a soft drop shadow.
    let emoji = "🔔"
    let fontSize = side * 0.62
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize)
    ]
    let str = NSAttributedString(string: emoji, attributes: attrs)
    let textSize = str.size()
    let drawRect = NSRect(
        x: (side - textSize.width) / 2,
        y: (side - textSize.height) / 2 - side * 0.04,
        width: textSize.width,
        height: textSize.height
    )

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    shadow.shadowOffset = NSSize(width: 0, height: -side * 0.012)
    shadow.shadowBlurRadius = side * 0.025
    shadow.set()

    str.draw(in: drawRect)

    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("PNG encoding failed at size \(pixels)px")
    }
    return png
}

// Resolve project root from script location.
let scriptPath = CommandLine.arguments[0]
let scriptURL = URL(fileURLWithPath: scriptPath).standardizedFileURL
let projectRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent().path

let workDir = NSTemporaryDirectory() + "AppIcon-\(UUID().uuidString).iconset"
let outputICNS = "\(projectRoot)/Resources/AppIcon.icns"

try? FileManager.default.removeItem(atPath: workDir)
try FileManager.default.createDirectory(atPath: workDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(
    atPath: "\(projectRoot)/Resources",
    withIntermediateDirectories: true
)

print("rendering iconset → \(workDir)")
for slot in slots {
    let data = renderIcon(pixels: slot.pixelSize)
    let url = URL(fileURLWithPath: "\(workDir)/\(slot.fileName)")
    try data.write(to: url)
    print("  ✓ \(slot.fileName) (\(slot.pixelSize)px)")
}

print("\ncompiling .icns → \(outputICNS)")
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", workDir, "-o", outputICNS]
try task.run()
task.waitUntilExit()

if task.terminationStatus != 0 {
    print("✗ iconutil exited with \(task.terminationStatus)")
    exit(1)
}

try? FileManager.default.removeItem(atPath: workDir)
print("✓ done")
