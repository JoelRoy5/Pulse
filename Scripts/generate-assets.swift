#!/usr/bin/env swift
//
// generate-assets.swift
//
// Deterministic, re-runnable generator for Pulse's app icon and image assets.
// No external design tool: draws with Core Graphics and writes PNGs directly
// into the asset catalogs.
//
//   swift Scripts/generate-assets.swift
//
// Design: a deep-navy field with a gold ECG heartbeat line arcing left→right.
// Its tallest spike is crossed by a short bar near the top, forming a subtle
// cross — heartbeat meeting Scripture.
//
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// MARK: - Palette

let bgColor    = CGColor(red: 0x0A/255.0, green: 0x0E/255.0, blue: 0x1A/255.0, alpha: 1) // #0A0E1A
let goldColor  = CGColor(red: 0xC9/255.0, green: 0xA9/255.0, blue: 0x6E/255.0, alpha: 1) // #C9A96E

let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

// MARK: - PNG writing

func writePNG(_ image: CGImage, to path: URL) {
    try? FileManager.default.createDirectory(
        at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let dest = CGImageDestinationCreateWithURL(
        path as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fputs("failed to create destination for \(path.path)\n", stderr); return
    }
    CGImageDestinationAddImage(dest, image, nil)
    if CGImageDestinationFinalize(dest) {
        print("wrote \(path.path)")
    } else {
        fputs("failed to write \(path.path)\n", stderr)
    }
}

func makeContext(size: Int, opaque: Bool) -> CGContext {
    let cs = CGColorSpaceCreateDeviceRGB()
    let alphaInfo: CGImageAlphaInfo = opaque ? .noneSkipLast : .premultipliedLast
    guard let ctx = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: cs, bitmapInfo: alphaInfo.rawValue) else {
        fatalError("could not create CGContext")
    }
    return ctx
}

// MARK: - ECG + cross drawing

/// Draws the gold ECG polyline (and its crossbar) onto `ctx` for a square of `s` points.
func drawHeartbeatCross(in ctx: CGContext, s: CGFloat, lineWidth: CGFloat) {
    // Normalized waypoints (x, y) with y measured from the TOP as a fraction.
    // Core Graphics origin is bottom-left, so we flip y when plotting.
    let pts: [(CGFloat, CGFloat)] = [
        (0.00, 0.50), (0.14, 0.50),
        (0.20, 0.42), (0.26, 0.50),          // P wave
        (0.34, 0.50),
        (0.38, 0.58),                         // Q dip
        (0.42, 0.14),                         // R spike (tallest)
        (0.46, 0.64),                         // S dip
        (0.50, 0.50),
        (0.60, 0.44), (0.68, 0.50),          // T wave
        (1.00, 0.50)
    ]

    let path = CGMutablePath()
    for (i, p) in pts.enumerated() {
        let x = p.0 * s
        let y = (1 - p.1) * s   // flip
        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
        else { path.addLine(to: CGPoint(x: x, y: y)) }
    }

    ctx.setStrokeColor(goldColor)
    ctx.setLineWidth(lineWidth)
    ctx.setLineJoin(.round)
    ctx.setLineCap(.round)
    ctx.addPath(path)
    ctx.strokePath()

    // Crossbar near the top of the R spike, forming a cross with the vertical rise.
    let barY = (1 - 0.24) * s
    let bar = CGMutablePath()
    bar.move(to: CGPoint(x: 0.35 * s, y: barY))
    bar.addLine(to: CGPoint(x: 0.49 * s, y: barY))
    ctx.addPath(bar)
    ctx.strokePath()
}

/// Full app-icon master: opaque navy field + heartbeat cross.
func makeIcon(size: Int) -> CGImage {
    let ctx = makeContext(size: size, opaque: true)
    let s = CGFloat(size)
    ctx.setFillColor(bgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))
    drawHeartbeatCross(in: ctx, s: s, lineWidth: s * 0.022)
    return ctx.makeImage()!
}

/// Transparent logo/particle glyph on a clear field.
func makeGlyph(size: Int, lineWidthFactor: CGFloat, crossOnly: Bool) -> CGImage {
    let ctx = makeContext(size: size, opaque: false)
    let s = CGFloat(size)
    ctx.setStrokeColor(goldColor)
    ctx.setLineWidth(s * lineWidthFactor)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    if crossOnly {
        // A simple centered cross.
        let v = CGMutablePath()
        v.move(to: CGPoint(x: s * 0.5, y: s * 0.12))
        v.addLine(to: CGPoint(x: s * 0.5, y: s * 0.88))
        let h = CGMutablePath()
        h.move(to: CGPoint(x: s * 0.28, y: s * 0.66))
        h.addLine(to: CGPoint(x: s * 0.72, y: s * 0.66))
        ctx.addPath(v); ctx.addPath(h); ctx.strokePath()
    } else {
        drawHeartbeatCross(in: ctx, s: s, lineWidth: s * lineWidthFactor)
    }
    return ctx.makeImage()!
}

// MARK: - Contents.json helpers

func writeContents(_ json: String, to dir: URL) {
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent("Contents.json")
    try? json.data(using: .utf8)!.write(to: url)
    print("wrote \(url.path)")
}

let iosIconContents = """
{
  "images" : [
    {
      "filename" : "icon_1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""

let watchIconContents = """
{
  "images" : [
    {
      "filename" : "icon_1024.png",
      "idiom" : "universal",
      "platform" : "watchos",
      "size" : "1024x1024"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""

func imagesetContents(_ filename: String) -> String {
    """
    {
      "images" : [
        { "filename" : "\(filename)", "idiom" : "universal", "scale" : "1x" },
        { "idiom" : "universal", "scale" : "2x" },
        { "idiom" : "universal", "scale" : "3x" }
      ],
      "info" : { "author" : "xcode", "version" : 1 }
    }
    """
}

// MARK: - Emit

let icon1024 = makeIcon(size: 1024)

// iOS app icon
let iosIconDir = repoRoot.appendingPathComponent("Pulse/Resources/Assets.xcassets/AppIcon.appiconset")
writePNG(icon1024, to: iosIconDir.appendingPathComponent("icon_1024.png"))
writeContents(iosIconContents, to: iosIconDir)

// watch app icon
let watchIconDir = repoRoot.appendingPathComponent("PulseWatch/Resources/Assets.xcassets/AppIcon.appiconset")
writePNG(icon1024, to: watchIconDir.appendingPathComponent("icon_1024.png"))
writeContents(watchIconContents, to: watchIconDir)

// logo_icon imageset (transparent)
let logoDir = repoRoot.appendingPathComponent("Pulse/Resources/Assets.xcassets/logo_icon.imageset")
writePNG(makeGlyph(size: 512, lineWidthFactor: 0.03, crossOnly: false), to: logoDir.appendingPathComponent("logo_icon.png"))
writeContents(imagesetContents("logo_icon.png"), to: logoDir)

// onboarding particles
let heartDir = repoRoot.appendingPathComponent("Pulse/Resources/Assets.xcassets/particles_heart.imageset")
writePNG(makeGlyph(size: 120, lineWidthFactor: 0.05, crossOnly: false), to: heartDir.appendingPathComponent("particles_heart.png"))
writeContents(imagesetContents("particles_heart.png"), to: heartDir)

let crossDir = repoRoot.appendingPathComponent("Pulse/Resources/Assets.xcassets/particles_cross.imageset")
writePNG(makeGlyph(size: 120, lineWidthFactor: 0.08, crossOnly: true), to: crossDir.appendingPathComponent("particles_cross.png"))
writeContents(imagesetContents("particles_cross.png"), to: crossDir)

print("done.")
