#!/usr/bin/swift
// Run from the repo root: swift scripts/generate_icon.swift
import Cocoa

let outputDir = "Sources/Gridly/Assets.xcassets/AppIcon.appiconset"

// MARK: - Drawing

func makeIcon(pixels: Int) -> NSBitmapImageRep {
    let s = CGFloat(pixels)
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(
        data: nil, width: pixels, height: pixels,
        bitsPerComponent: 8, bytesPerRow: 0, space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    // ── Background ──────────────────────────────────────────────────────────
    let bgR = s * 0.20
    ctx.setFillColor(CGColor(red: 0.10, green: 0.10, blue: 0.16, alpha: 1))
    ctx.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: s, height: s),
                       cornerWidth: bgR, cornerHeight: bgR, transform: nil))
    ctx.fillPath()

    // ── Four window panes ───────────────────────────────────────────────────
    let pad: CGFloat = s * 0.14
    let gap: CGFloat = s * 0.055
    let pw:  CGFloat = (s - 2*pad - gap) / 2
    let ph:  CGFloat = (s - 2*pad - gap) / 2
    let pr:  CGFloat = s * 0.05

    // (x, y) in CoreGraphics coords where y=0 is bottom
    let panes: [(CGFloat, CGFloat, CGColor)] = [
        (pad,        pad + ph + gap, CGColor(red: 0.36, green: 0.58, blue: 1.00, alpha: 1)), // top-left  — blue
        (pad+pw+gap, pad + ph + gap, CGColor(red: 0.32, green: 0.84, blue: 0.62, alpha: 1)), // top-right — green
        (pad,        pad,            CGColor(red: 1.00, green: 0.58, blue: 0.28, alpha: 1)), // bot-left  — orange
        (pad+pw+gap, pad,            CGColor(red: 0.76, green: 0.48, blue: 1.00, alpha: 1)), // bot-right — purple
    ]

    for (x, y, color) in panes {
        let rect = CGRect(x: x, y: y, width: pw, height: ph)
        ctx.setFillColor(color)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: pr, cornerHeight: pr, transform: nil))
        ctx.fillPath()
    }

    return NSBitmapImageRep(cgImage: ctx.makeImage()!)
}

// MARK: - Output

// (pixelSize, filename)
let sizes: [(Int, String)] = [
    (16,   "icon_16x16.png"),
    (32,   "icon_16x16@2x.png"),
    (32,   "icon_32x32.png"),
    (64,   "icon_32x32@2x.png"),
    (128,  "icon_128x128.png"),
    (256,  "icon_128x128@2x.png"),
    (256,  "icon_256x256.png"),
    (512,  "icon_256x256@2x.png"),
    (512,  "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

var cache: [Int: NSBitmapImageRep] = [:]

for (px, filename) in sizes {
    let rep: NSBitmapImageRep
    if let cached = cache[px] {
        rep = cached
    } else {
        rep = makeIcon(pixels: px)
        cache[px] = rep
    }
    guard let data = rep.representation(using: .png, properties: [:]) else {
        print("✗ Failed to encode \(filename)"); continue
    }
    let url = URL(fileURLWithPath: "\(outputDir)/\(filename)")
    try! data.write(to: url)
    print("✓ \(filename)  (\(px)×\(px))")
}
print("Done.")
