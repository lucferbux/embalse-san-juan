import SwiftUI
import WidgetKit
import XCTest
@testable import EmbalseKit

/// Renders each widget to `build/widget-snapshots` for review with `make widgets`.
/// It asserts that rendering works; how they look still takes a person looking at the images.
@MainActor
final class WidgetSnapshotTests: XCTestCase {
    private let output = Fixture.root.appending(path: "build/widget-snapshots")
    private lazy var now = (try? Fixture.snapshot().live.observedAt.addingTimeInterval(1800)) ?? .now

    /// The fixture only spans 2 days, so charts get a believable 90-day curve.
    private func withLongSeries() throws -> Snapshot {
        var snapshot = try Fixture.snapshot()
        let calendar = Calendar(identifier: .gregorian)
        snapshot.daily = (0..<90).map { offset in
            let date = calendar.date(byAdding: .day, value: offset - 89, to: snapshot.live.observedAt)!
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            let text = String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
            return Snapshot.DailyPoint(date: text, volumeHm3: 84 - Double(offset) * 0.19 + sin(Double(offset) / 6))
        }
        return snapshot
    }

    private func render(_ name: String, size: CGSize, scheme: ColorScheme = .light, corner: CGFloat = 22, @ViewBuilder content: () -> some View) throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let view = content()
            .frame(width: size.width, height: size.height)
            .background(scheme == .dark ? Color.black : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .padding(8)
            .background(Color(white: scheme == .dark ? 0.15 : 0.85))
            .environment(\.colorScheme, scheme)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage)
        try XCTUnwrap(image.pngData()).write(to: output.appending(path: "\(name).png"))
    }

    func testSmall() throws {
        let snapshot = try Fixture.snapshot()
        let size = CGSize(width: 170, height: 170)
        try render("small-light", size: size) { SmallWidgetView(snapshot: snapshot, now: now) }
        try render("small-dark", size: size, scheme: .dark) { SmallWidgetView(snapshot: snapshot, now: now) }
    }

    func testSmallAtExtremes() throws {
        var snapshot = try Fixture.snapshot()
        let size = CGSize(width: 170, height: 170)
        snapshot.live.percent = 8
        try render("small-low", size: size) { SmallWidgetView(snapshot: snapshot, now: now) }
        snapshot.live.percent = 97
        try render("small-high", size: size) { SmallWidgetView(snapshot: snapshot, now: now) }
    }

    func testSmallWhenStale() throws {
        let snapshot = try Fixture.snapshot()
        let later = snapshot.live.observedAt.addingTimeInterval(24 * 3600)
        try render("small-stale", size: CGSize(width: 170, height: 170)) { SmallWidgetView(snapshot: snapshot, now: later) }
    }

    func testMedium() throws {
        let snapshot = try withLongSeries()
        let size = CGSize(width: 364, height: 170)
        try render("medium-light", size: size) { MediumWidgetView(snapshot: snapshot, now: now) }
        try render("medium-dark", size: size, scheme: .dark) { MediumWidgetView(snapshot: snapshot, now: now) }
    }

    func testLarge() throws {
        let snapshot = try withLongSeries()
        let size = CGSize(width: 364, height: 382)
        try render("large-light", size: size) { LargeWidgetView(snapshot: snapshot, now: now) }
        try render("large-dark", size: size, scheme: .dark) { LargeWidgetView(snapshot: snapshot, now: now) }
    }

    func testTinted() throws {
        let snapshot = try Fixture.snapshot()
        try render("small-tinted", size: CGSize(width: 170, height: 170), scheme: .dark) {
            SmallWidgetView(snapshot: snapshot, now: now)
                .environment(\.widgetRenderingMode, .accented)
                .background(Color(red: 0.1, green: 0.15, blue: 0.3))
        }
    }

    func testLockScreen() throws {
        let snapshot = try Fixture.snapshot()
        try render("lock-circular", size: CGSize(width: 76, height: 76), scheme: .dark, corner: 38) {
            CircularLockWidgetView(snapshot: snapshot)
                .environment(\.widgetRenderingMode, .accented)
        }
        try render("lock-rectangular", size: CGSize(width: 172, height: 76), scheme: .dark, corner: 12) {
            RectangularLockWidgetView(snapshot: snapshot)
                .environment(\.widgetRenderingMode, .accented)
        }
        try render("lock-inline", size: CGSize(width: 240, height: 28), scheme: .dark, corner: 6) {
            InlineLockWidgetView(snapshot: snapshot)
                .environment(\.widgetRenderingMode, .accented)
        }
    }
}
