#!/usr/bin/env swift
// Draws the App Store header (3840x1646) and search results (3840x2560) images, with the icon's water.
// The search results image shows real screenshots, so run scripts/export-screenshots.sh first.
// Usage: swift scripts/make-creative-assets.swift
import AppKit
import CoreGraphics

let screenshots = "fastlane/screenshots/es-ES"
let output = URL(filePath: "fastlane/creative_assets", directoryHint: .isDirectory)

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

func wave(width: CGFloat, baseline: CGFloat, phase: CGFloat, amplitude: CGFloat, cycles: CGFloat) -> CGPath {
    let path = CGMutablePath()
    path.move(to: .zero)
    for x in stride(from: CGFloat(0), through: width, by: 4) {
        path.addLine(to: CGPoint(x: x, y: baseline + sin(x / width * 2 * .pi * cycles + phase) * amplitude))
    }
    path.addLine(to: CGPoint(x: width, y: 0))
    path.closeSubpath()
    return path
}

func fill(_ context: CGContext, path: CGPath?, height: CGFloat, top: CGColor, bottom: CGColor) {
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [top, bottom] as CFArray, locations: [0, 1])!
    context.saveGState()
    if let path {
        context.addPath(path)
        context.clip()
    }
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: height), end: .zero, options: [])
    context.restoreGState()
}

/// The sky and two waves, the same colours as the app icon.
func drawWater(_ context: CGContext, width: CGFloat, height: CGFloat, level: CGFloat) {
    fill(context, path: nil, height: height, top: color(0.86, 0.94, 1.0), bottom: color(0.97, 0.99, 1.0))
    fill(context, path: wave(width: width, baseline: height * (level + 0.05), phase: 2.6, amplitude: height * 0.035, cycles: 1.3),
         height: height, top: color(0.45, 0.76, 1.0), bottom: color(0.30, 0.62, 0.98))
    fill(context, path: wave(width: width, baseline: height * level, phase: 0.5, amplitude: height * 0.04, cycles: 1.1),
         height: height, top: color(0.12, 0.53, 0.96), bottom: color(0.01, 0.22, 0.58))
}

func drawText(_ text: String, size: CGFloat, weight: NSFont.Weight, color textColor: NSColor, center: CGPoint, width: CGFloat) {
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: textColor, .paragraphStyle: style,
    ]
    let string = NSAttributedString(string: text, attributes: attributes)
    let box = string.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin])
    string.draw(with: CGRect(x: center.x - width / 2, y: center.y - box.height / 2, width: width, height: box.height), options: [.usesLineFragmentOrigin])
}

/// A screenshot with rounded corners and a soft shadow, fitted to a height and centred on `centerX`.
func drawScreenshot(_ context: CGContext, file: String, centerX: CGFloat, bottom: CGFloat, height: CGFloat, radius: CGFloat) throws {
    guard let image = NSImage(contentsOfFile: "\(screenshots)/\(file)")?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: file])
    }
    let width = height * CGFloat(image.width) / CGFloat(image.height)
    let rect = CGRect(x: centerX - width / 2, y: bottom, width: width, height: height)
    let shape = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -24), blur: 90, color: color(0, 0.1, 0.3, 0.4))
    context.addPath(shape)
    context.setFillColor(color(1, 1, 1))
    context.fillPath()
    context.restoreGState()
    context.saveGState()
    context.addPath(shape)
    context.clip()
    context.draw(image, in: rect)
    context.restoreGState()
}

func render(_ name: String, width: Int, height: Int, draw: (CGContext) throws -> Void) throws {
    // No alpha: App Store Connect refuses images with transparency.
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    try draw(context)
    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
    try bitmap.representation(using: .png, properties: [:])!.write(to: output.appending(path: name))
}

try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

try render("header-3840x1646.png", width: 3840, height: 1646) { context in
    drawWater(context, width: 3840, height: 1646, level: 0.56)
    drawText("Cuánta agua hay en San Juan", size: 190, weight: .bold, color: .white, center: CGPoint(x: 1920, y: 420), width: 3200)
}

try render("search-results-3840x2560.png", width: 3840, height: 2560) { context in
    drawWater(context, width: 3840, height: 2560, level: 0.5)
    drawText("Nivel, caudal e histórico del embalse", size: 150, weight: .bold, color: NSColor(cgColor: color(0.01, 0.2, 0.5))!,
             center: CGPoint(x: 1920, y: 2340), width: 3400)
    let height: CGFloat = 2010
    try drawScreenshot(context, file: "iphone-69-02-boletin.png", centerX: 760, bottom: 90, height: height, radius: 130)
    try drawScreenshot(context, file: "iphone-69-01-ahora.png", centerX: 1920, bottom: 90, height: height, radius: 130)
    try drawScreenshot(context, file: "iphone-69-04-historico.png", centerX: 3080, bottom: 90, height: height, radius: 130)
}
