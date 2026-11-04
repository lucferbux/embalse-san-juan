#!/usr/bin/env swift
// Draws the App Store header (3840x1646) and search results (3840x2560) images, with the icon's water,
// Google Play's feature graphic (1024x500) and icon (512x512), and the store screenshots: each raw shot
// from fastlane/screenshots_raw on the same water, with a headline, at the size it was taken.
// Run scripts/export-screenshots.sh and scripts/export-android-screenshots.sh first.
// Usage: swift scripts/make-creative-assets.swift
import AppKit
import CoreGraphics

let screenshots = "fastlane/screenshots_raw/ios"
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
let play = "../metadata/android/es-ES/images"
try FileManager.default.createDirectory(at: output.appending(path: play), withIntermediateDirectories: true)

try render("\(play)/featureGraphic.png", width: 1024, height: 500) { context in
    drawWater(context, width: 1024, height: 500, level: 0.56)
    drawText("Cuánta agua hay en San Juan", size: 56, weight: .bold, color: .white, center: CGPoint(x: 512, y: 130), width: 900)
}

try render("\(play)/icon.png", width: 512, height: 512) { context in
    guard let icon = NSImage(contentsOfFile: "ios/App/Assets.xcassets/AppIcon.appiconset/icon-light.png")?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        throw CocoaError(.fileNoSuchFile)
    }
    context.draw(icon, in: CGRect(x: 0, y: 0, width: 512, height: 512))
}

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

// MARK: - Store screenshots

/// Headline and subtitle for each screen, keyed by the end of the file name.
let captions: [String: (String, String)] = [
    "01-ahora": ("El embalse, ahora", "Nivel, volumen y tendencia, cada hora"),
    "02-boletin": ("¿Más o menos que otros años?", "El boletín semanal, con el año pasado y la media de 10 años"),
    "03-alberche": ("Todo el Alberche", "Burguillo, San Juan y Picadas, y la lluvia en la cuenca"),
    "04-historico": ("Desde 1988", "Cada semana del histórico, con mínimos y máximos"),
    "05-ficha": ("Datos oficiales", "SAIH Tajo y MITECO, con su fuente y su fecha"),
    "05-widget": ("Un vistazo, sin abrir la app", "Widgets que suben y bajan con el agua"),
]

func caption(for file: String) -> (String, String)? {
    // Watch shots stay as they are: the store draws its own watch around them.
    guard !file.hasPrefix("watch-") else { return nil }
    return captions.first { file.hasSuffix("\($0.key).png") }?.value
}

/// The shot in a dark bezel, sinking below the bottom edge, with the headline in the sky above it.
func frame(_ context: CGContext, shot: CGImage, width: CGFloat, height: CGFloat, title: String, subtitle: String) {
    let wide = width / height > 0.62
    // Text scales with the short side, so landscape shots (iPhone Duo open) don't get a giant headline.
    let unit = min(width, height * 0.75)
    let small = wide && width <= height
    drawWater(context, width: width, height: height, level: 0.4)
    let navy = NSColor(cgColor: color(0.01, 0.2, 0.5))!
    drawText(title, size: unit * (small ? 0.058 : 0.074), weight: .bold, color: navy,
             center: CGPoint(x: width / 2, y: height * 0.905), width: width * 0.88)
    drawText(subtitle, size: unit * (small ? 0.03 : 0.04), weight: .medium, color: NSColor(cgColor: color(0.16, 0.33, 0.6))!,
             center: CGPoint(x: width / 2, y: height * (width > height ? 0.83 : 0.845)), width: width * 0.84)

    let screenWidth = width > height ? width * 0.7 : width * (wide ? 0.8 : 0.78)
    let screenHeight = screenWidth * CGFloat(shot.height) / CGFloat(shot.width)
    let screen = CGRect(x: (width - screenWidth) / 2, y: height * (width > height ? 0.76 : 0.79) - screenHeight, width: screenWidth, height: screenHeight)
    let bezel = screenWidth * 0.022
    let radius = screenWidth * (wide ? 0.04 : 0.11)
    let body = screen.insetBy(dx: -bezel, dy: -bezel)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: radius + bezel, cornerHeight: radius + bezel, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -height * 0.01), blur: width * 0.06, color: color(0, 0.08, 0.25, 0.45))
    context.addPath(bodyPath)
    context.setFillColor(color(0.06, 0.08, 0.12))
    context.fillPath()
    context.restoreGState()
    context.saveGState()
    context.addPath(CGPath(roundedRect: screen, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.clip()
    context.draw(shot, in: screen)
    context.restoreGState()
}

/// Frames every raw shot in `from` that has a caption into `to`, and copies the rest unchanged.
/// `rename` maps a raw file to its folder and name under fastlane/.
func frameAll(from: String, rename: (String) -> String) throws {
    let files = try FileManager.default.subpathsOfDirectory(atPath: from).filter { $0.hasSuffix(".png") }.sorted()
    for file in files {
        let target = output.appending(path: "..").appending(path: rename(file))
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let (title, subtitle) = caption(for: file),
              let shot = NSImage(contentsOfFile: "\(from)/\(file)")?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            try? FileManager.default.removeItem(at: target)
            try FileManager.default.copyItem(atPath: "\(from)/\(file)", toPath: target.path)
            continue
        }
        try render("../\(rename(file))", width: shot.width, height: shot.height) { context in
            frame(context, shot: shot, width: CGFloat(shot.width), height: CGFloat(shot.height), title: title, subtitle: subtitle)
        }
        print("   \(rename(file))")
    }
}

// Duo shots go apart from the rest: deliver doesn't recognise their sizes.
try frameAll(from: "fastlane/screenshots_raw/ios") { file in
    file.hasPrefix("duo-") ? "screenshots_duo/es-ES/\(file)" : "screenshots/es-ES/\(file)"
}
try frameAll(from: "fastlane/screenshots_raw/android") { "metadata/android/es-ES/images/\($0)" }
