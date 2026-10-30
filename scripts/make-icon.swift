#!/usr/bin/env swift
// Draws the app icon: water rising to about two thirds, with a gentle wave.
// Usage: swift scripts/make-icon.swift ios/App/Assets.xcassets/AppIcon.appiconset
import AppKit
import CoreGraphics

let size = 1024
let outputDirectory = URL(filePath: CommandLine.arguments[1], directoryHint: .isDirectory)

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

func wave(level: CGFloat, phase: CGFloat, amplitude: CGFloat) -> CGPath {
    let width = CGFloat(size)
    let baseline = width * level
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 0, y: 0))
    for x in stride(from: CGFloat(0), through: width, by: 4) {
        path.addLine(to: CGPoint(x: x, y: baseline + sin(x / width * 2 * .pi + phase) * amplitude))
    }
    path.addLine(to: CGPoint(x: width, y: 0))
    path.closeSubpath()
    return path
}

func fill(_ context: CGContext, path: CGPath?, top: CGColor, bottom: CGColor) {
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [top, bottom] as CFArray, locations: [0, 1])!
    context.saveGState()
    if let path {
        context.addPath(path)
        context.clip()
    }
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: CGFloat(size)), end: .zero, options: [])
    context.restoreGState()
}

func render(_ name: String, opaque: Bool, draw: (CGContext) -> Void) throws {
    let alpha: CGImageAlphaInfo = opaque ? .noneSkipLast : .premultipliedLast
    let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: alpha.rawValue
    )!
    draw(context)
    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
    try bitmap.representation(using: .png, properties: [:])!.write(to: outputDirectory.appending(path: name))
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let backWave = wave(level: 0.64, phase: 2.6, amplitude: 46)
let frontWave = wave(level: 0.58, phase: 0.5, amplitude: 52)

try render("icon-light.png", opaque: true) { context in
    fill(context, path: nil, top: color(0.86, 0.94, 1.0), bottom: color(0.97, 0.99, 1.0))
    fill(context, path: backWave, top: color(0.45, 0.76, 1.0), bottom: color(0.30, 0.62, 0.98))
    fill(context, path: frontWave, top: color(0.12, 0.53, 0.96), bottom: color(0.01, 0.22, 0.58))
}

try render("icon-dark.png", opaque: true) { context in
    fill(context, path: nil, top: color(0.03, 0.06, 0.12), bottom: color(0.07, 0.12, 0.21))
    fill(context, path: backWave, top: color(0.20, 0.47, 0.82), bottom: color(0.12, 0.33, 0.66))
    fill(context, path: frontWave, top: color(0.16, 0.56, 0.96), bottom: color(0.02, 0.25, 0.62))
}

// Tinted icons are greyscale: iOS applies the user's tint to the luminance.
try render("icon-tinted.png", opaque: true) { context in
    context.setFillColor(color(0, 0, 0))
    context.fill(CGRect(x: 0, y: 0, width: size, height: size))
    fill(context, path: backWave, top: color(0.42, 0.42, 0.42), bottom: color(0.30, 0.30, 0.30))
    fill(context, path: frontWave, top: color(1, 1, 1), bottom: color(0.62, 0.62, 0.62))
}
