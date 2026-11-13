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
    try drawScreenshot(context, file: "iphone-69-02-ano.png", centerX: 760, bottom: 90, height: height, radius: 130)
    try drawScreenshot(context, file: "iphone-69-01-ahora.png", centerX: 1920, bottom: 90, height: height, radius: 130)
    try drawScreenshot(context, file: "iphone-69-03-historico.png", centerX: 3080, bottom: 90, height: height, radius: 130)
}

// MARK: - Store screenshots

/// One store image: a small label, the headline and a line under it, and whether it sits on deep water (white text)
/// or on the sky with waves at the bottom (navy text). The styles alternate, so the set reads as a sequence.
struct Caption {
    var label: String
    var title: String
    var subtitle: String
    var deep: Bool
}

/// Keyed by the end of the file name. Watch shots stay as they are: the store draws its own watch around them.
let captions: [String: Caption] = [
    "01-ahora": Caption(label: "SAIH Tajo · cada hora", title: "El agua de San Juan, ahora",
                        subtitle: "Nivel, volumen y tendencia, con el agua moviéndose a su altura real", deep: true),
    "02-ano": Caption(label: "Hoy | Año", title: "Un año de un vistazo",
                      subtitle: "La misma agua se convierte en los últimos 12 meses, con el año pasado detrás", deep: false),
    "03-historico": Caption(label: "MITECO · desde 1988", title: "¿Más o menos que otros años?",
                            subtitle: "Este año, el anterior, la media de 10 años y el rango de cada semana", deep: true),
    "04-el-rio": Caption(label: "Alberche", title: "Todo el río",
                         subtitle: "Burguillo, San Juan y Picadas, de aguas arriba a aguas abajo, y la lluvia en la cuenca", deep: false),
    "05-widgets": Caption(label: "Widgets", title: "Sin abrir la app",
                          subtitle: "En la pantalla de inicio y de bloqueo, con el agua a su altura", deep: true),
]

func caption(for file: String) -> Caption? {
    guard !file.hasPrefix("watch-") else { return nil }
    return captions.first { file.hasSuffix("\($0.key).png") }?.value
}

let navy = NSColor(cgColor: color(0.02, 0.17, 0.40))!

/// Deep water, top to bottom, with a lighter crest across the top third.
func drawDeep(_ context: CGContext, width: CGFloat, height: CGFloat) {
    fill(context, path: nil, height: height, top: color(0.05, 0.42, 0.70), bottom: color(0.01, 0.13, 0.33))
    context.saveGState()
    context.setAlpha(0.18)
    fill(context, path: wave(width: width, baseline: height * 0.72, phase: 1.2, amplitude: height * 0.018, cycles: 1.4),
         height: height, top: color(0.56, 0.82, 1.0), bottom: color(0.56, 0.82, 1.0, 0))
    context.restoreGState()
}

func drawLabel(_ text: String, deep: Bool, center: CGPoint, size: CGFloat) {
    let font = NSFont.systemFont(ofSize: size, weight: .semibold)
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: deep ? NSColor.white : navy, .kern: size * 0.04]
    let string = NSAttributedString(string: text.uppercased(), attributes: attributes)
    let box = string.size()
    let pill = CGRect(x: center.x - box.width / 2 - size * 0.9, y: center.y - box.height / 2 - size * 0.45,
                      width: box.width + size * 1.8, height: box.height + size * 0.9)
    let context = NSGraphicsContext.current!.cgContext
    context.saveGState()
    context.addPath(CGPath(roundedRect: pill, cornerWidth: pill.height / 2, cornerHeight: pill.height / 2, transform: nil))
    context.setFillColor(deep ? color(1, 1, 1, 0.16) : color(0.02, 0.17, 0.40, 0.08))
    context.fillPath()
    context.restoreGState()
    string.draw(at: CGPoint(x: center.x - box.width / 2, y: center.y - box.height / 2))
}

func roundedTitle(_ text: String, size: CGFloat, color textColor: NSColor, center: CGPoint, width: CGFloat) {
    let base = NSFont.systemFont(ofSize: size, weight: .heavy)
    let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: size) } ?? base
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    style.lineHeightMultiple = 0.92
    let string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: textColor, .paragraphStyle: style])
    let box = string.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin])
    string.draw(with: CGRect(x: center.x - width / 2, y: center.y - box.height / 2, width: width, height: box.height), options: [.usesLineFragmentOrigin])
}

/// Draws `string` with its top at `top` (CoreGraphics coordinates, y up), centred, and returns its height.
@discardableResult
func drawBlock(_ string: NSAttributedString, top: CGFloat, centerX: CGFloat, width: CGFloat) -> CGFloat {
    let box = string.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin])
    string.draw(with: CGRect(x: centerX - width / 2, y: top - box.height, width: width, height: box.height), options: [.usesLineFragmentOrigin])
    return box.height
}

func centred(_ text: String, font: NSFont, color textColor: NSColor, lineHeight: CGFloat = 1) -> NSAttributedString {
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    style.lineHeightMultiple = lineHeight
    return NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: textColor, .paragraphStyle: style])
}

/// The background, then the label, headline and line under it stacked from the top by their measured heights, so a
/// two-line headline never runs into the text below it. Returns where the device or content may start (its top).
func drawBackdrop(_ context: CGContext, width: CGFloat, height: CGFloat, caption: Caption) -> CGFloat {
    let unit = min(width, height * 0.56)
    if caption.deep {
        drawDeep(context, width: width, height: height)
    } else {
        drawWater(context, width: width, height: height, level: 0.22)
    }
    let ink = caption.deep ? NSColor.white : navy
    let soft = caption.deep ? NSColor.white.withAlphaComponent(0.82) : NSColor(cgColor: color(0.10, 0.27, 0.52))!
    var cursor = height - unit * 0.07
    let labelSize = unit * 0.03
    let pillHeight = labelSize * 2.1
    drawLabel(caption.label, deep: caption.deep, center: CGPoint(x: width / 2, y: cursor - pillHeight / 2), size: labelSize)
    cursor -= pillHeight + unit * 0.03
    let base = NSFont.systemFont(ofSize: unit * 0.088, weight: .heavy)
    let titleFont = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: unit * 0.088) } ?? base
    cursor -= drawBlock(centred(caption.title, font: titleFont, color: ink, lineHeight: 0.92), top: cursor, centerX: width / 2, width: width * 0.88)
    cursor -= unit * 0.022
    cursor -= drawBlock(centred(caption.subtitle, font: .systemFont(ofSize: unit * 0.036, weight: .medium), color: soft),
                        top: cursor, centerX: width / 2, width: width * 0.8)
    return cursor - unit * 0.06
}

/// The shot in a dark bezel, sinking below the bottom edge so the top of the screen, the water card, is what you see.
func frame(_ context: CGContext, shot: CGImage, width: CGFloat, height: CGFloat, caption: Caption) {
    let top = drawBackdrop(context, width: width, height: height, caption: caption)
    let tablet = width / height > 0.7
    let screenWidth = width * (tablet ? 0.84 : 0.80)
    let screenHeight = screenWidth * CGFloat(shot.height) / CGFloat(shot.width)
    let screen = CGRect(x: (width - screenWidth) / 2, y: top - screenHeight, width: screenWidth, height: screenHeight)
    let bezel = screenWidth * (tablet ? 0.018 : 0.024)
    let radius = screenWidth * (tablet ? 0.045 : 0.12)
    let body = screen.insetBy(dx: -bezel, dy: -bezel)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: radius + bezel, cornerHeight: radius + bezel, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -height * 0.012), blur: width * 0.07, color: color(0, 0.05, 0.2, 0.55))
    context.addPath(bodyPath)
    context.setFillColor(color(0.05, 0.06, 0.09))
    context.fillPath()
    context.restoreGState()
    // A thin light edge on the bezel, like a real frame catching the light.
    context.saveGState()
    context.addPath(bodyPath)
    context.setStrokeColor(color(1, 1, 1, 0.14))
    context.setLineWidth(bezel * 0.25)
    context.strokePath()
    context.restoreGState()
    context.saveGState()
    context.addPath(CGPath(roundedRect: screen, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.clip()
    context.draw(shot, in: screen)
    context.restoreGState()
}

/// A widget render from WidgetSnapshotTests, without the 8 pt grey margin the test adds, with its corners rounded again.
func widget(_ name: String) -> CGImage? {
    guard let image = NSImage(contentsOfFile: "build/widget-snapshots/\(name).png")?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
    let inset = 24
    return image.cropping(to: CGRect(x: inset, y: inset, width: image.width - inset * 2, height: image.height - inset * 2))
}

func drawWidget(_ context: CGContext, _ image: CGImage, in rect: CGRect, radius: CGFloat) {
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -rect.height * 0.03), blur: rect.width * 0.08, color: color(0, 0.05, 0.2, 0.45))
    context.addPath(path)
    context.setFillColor(color(1, 1, 1))
    context.fillPath()
    context.restoreGState()
    context.saveGState()
    context.addPath(path)
    context.clip()
    context.draw(image, in: rect)
    context.restoreGState()
}

/// "Sin abrir la app": the widgets as a Home Screen, from scripts/store-widgets.sh's renders.
func renderWidgetsShot(name: String, width: Int, height: Int) throws {
    guard let large = widget("store-year"), let small = widget("store-small"), let river = widget("store-river"),
          let medium = widget("store-medium") else {
        print("   (no widget renders: run scripts/store-widgets.sh)")
        return
    }
    try render("../\(name)", width: width, height: height) { context in
        let w = CGFloat(width), h = CGFloat(height)
        let top = drawBackdrop(context, width: w, height: h, caption: captions["05-widgets"]!)
        let margin = w * 0.08, gap = w * 0.05
        let full = w - margin * 2
        let half = (full - gap) / 2
        let radius = full * 0.065
        var y = top - full * 170 / 364
        drawWidget(context, large, in: CGRect(x: margin, y: y, width: full, height: full * 170 / 364), radius: radius)
        y -= gap + half
        drawWidget(context, small, in: CGRect(x: margin, y: y, width: half, height: half), radius: radius)
        drawWidget(context, river, in: CGRect(x: margin + half + gap, y: y, width: half, height: half), radius: radius)
        y -= gap + full * 170 / 364
        drawWidget(context, medium, in: CGRect(x: margin, y: y, width: full, height: full * 170 / 364), radius: radius)
    }
    print("   \(name)")
}

/// Frames every raw shot in `from` that has a caption into `to`, and copies the rest unchanged.
/// `rename` maps a raw file to its folder and name under fastlane/.
func frameAll(from: String, rename: (String) -> String) throws {
    let files = try FileManager.default.subpathsOfDirectory(atPath: from).filter { $0.hasSuffix(".png") }.sorted()
    for file in files {
        let target = output.appending(path: "..").appending(path: rename(file))
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let caption = caption(for: file),
              let shot = NSImage(contentsOfFile: "\(from)/\(file)")?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            try? FileManager.default.removeItem(at: target)
            try FileManager.default.copyItem(atPath: "\(from)/\(file)", toPath: target.path)
            continue
        }
        try render("../\(rename(file))", width: shot.width, height: shot.height) { context in
            frame(context, shot: shot, width: CGFloat(shot.width), height: CGFloat(shot.height), caption: caption)
        }
        print("   \(rename(file))")
    }
}

// Old shots from earlier sets would be uploaded too: start clean.
for folder in ["fastlane/screenshots/es-ES", "fastlane/metadata/android/es-ES/images/phoneScreenshots",
               "fastlane/metadata/android/es-ES/images/sevenInchScreenshots", "fastlane/metadata/android/es-ES/images/tenInchScreenshots"] {
    try? FileManager.default.removeItem(atPath: folder)
}

// Duo shots go apart from the rest: deliver doesn't recognise their sizes.
try frameAll(from: "fastlane/screenshots_raw/ios") { file in
    file.hasPrefix("duo-") ? "screenshots_duo/es-ES/\(file)" : "screenshots/es-ES/\(file)"
}
try frameAll(from: "fastlane/screenshots_raw/android") { "metadata/android/es-ES/images/\($0)" }
try renderWidgetsShot(name: "screenshots/es-ES/iphone-69-05-widgets.png", width: 1320, height: 2868)
