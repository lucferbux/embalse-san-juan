#!/usr/bin/env swift
// Makes the images in firebase/site/img from the raw store screenshots and the widget snapshots.
// Widgets are cropped to the widget itself, with transparent rounded corners, so the page needs no clipping.
// Run scripts/export-screenshots.sh, scripts/export-android-screenshots.sh and `make widgets` first.
// Usage: swift scripts/make-site-images.swift
import AppKit
import CoreGraphics

let output = "firebase/site/img"
let raw = "fastlane/screenshots_raw"
let widgets = "build/widget-snapshots"

func load(_ path: String) throws -> CGImage {
    guard let image = NSImage(contentsOfFile: path)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: path])
    }
    return image
}

func write(_ image: CGImage, to name: String, jpeg: Bool) throws {
    let bitmap = NSBitmapImageRep(cgImage: image)
    let data = jpeg
        ? bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8])!
        : bitmap.representation(using: .png, properties: [:])!
    try data.write(to: URL(filePath: "\(output)/\(name)"))
    print("   \(name)  \(image.width)x\(image.height)")
}

/// Scales an image so its longer side is at most `longest` pixels.
func resized(_ image: CGImage, longest: Int, alpha: Bool) -> CGImage {
    let scale = min(1, CGFloat(longest) / CGFloat(max(image.width, image.height)))
    let width = Int(CGFloat(image.width) * scale), height = Int(CGFloat(image.height) * scale)
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: (alpha ? CGImageAlphaInfo.premultipliedLast : .noneSkipLast).rawValue)!
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()!
}

/// WidgetSnapshotTests draws each widget at 3x with an 8 pt margin and 22 pt continuous corners.
func widget(_ image: CGImage) -> CGImage {
    let margin = 8 * 3, radius: CGFloat = 22 * 3
    let crop = image.cropping(to: CGRect(x: margin, y: margin, width: image.width - 2 * margin, height: image.height - 2 * margin))!
    let rect = CGRect(x: 0, y: 0, width: crop.width, height: crop.height)
    let context = CGContext(data: nil, width: crop.width, height: crop.height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // A pixel in, so neither the margin's grey nor the white behind the widget survives the antialiased edge.
    let shape = NSBezierPath(roundedRect: rect.insetBy(dx: 2, dy: 2), xRadius: radius, yRadius: radius)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    shape.addClip()
    context.draw(crop, in: rect)
    return context.makeImage()!
}

try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)

for name in ["01-ahora", "02-boletin", "03-alberche", "04-historico"] {
    try write(resized(try load("\(raw)/ios/iphone-69-\(name).png"), longest: 1800, alpha: false), to: "iphone-\(name).jpg", jpeg: true)
}
try write(resized(try load("\(raw)/ios/ipad-13-01-ahora.png"), longest: 1800, alpha: false), to: "ipad.jpg", jpeg: true)
try write(resized(try load("\(raw)/ios/duo-inner-01-ahora.png"), longest: 1800, alpha: false), to: "duo.jpg", jpeg: true)
try write(resized(try load("\(raw)/android/phoneScreenshots/01-ahora.png"), longest: 1600, alpha: false), to: "android.jpg", jpeg: true)
try write(try load("\(raw)/ios/watch-01-ahora.png"), to: "watch.png", jpeg: false)
for name in ["small-light", "small-dark", "medium-light", "large-light"] {
    try write(resized(widget(try load("\(widgets)/\(name).png")), longest: 900, alpha: true), to: "widget-\(name).png", jpeg: false)
}
try write(resized(try load("ios/App/Assets.xcassets/AppIcon.appiconset/icon-light.png"), longest: 256, alpha: false), to: "icon.png", jpeg: false)
