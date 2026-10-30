import Foundation

public extension Snapshot {
    /// Shown while a widget has no data yet, and in the widget gallery. WidgetKit redacts its values.
    static let placeholder: Snapshot = {
        let now = Date.now
        let days = (0..<30).map { offset -> DailyPoint in
            let date = Calendar(identifier: .gregorian).date(byAdding: .day, value: offset - 29, to: now) ?? now
            let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
            let text = String(format: "%04d-%02d-%02d", parts.year ?? 2026, parts.month ?? 1, parts.day ?? 1)
            return DailyPoint(date: text, volumeHm3: 70 - Double(offset) * 0.1)
        }
        return Snapshot(
            schemaVersion: 1,
            generatedAt: now,
            reservoir: Reservoir(
                id: "san-juan", name: "San Juan", river: "Alberche", basin: "Tajo", province: "Madrid",
                municipality: "San Martín de Valdeiglesias", damType: "Gravedad", yearBuilt: 1955, surfaceHa: 650, uses: []
            ),
            live: Live(
                observedAt: now, volumeHm3: 67, percent: 48.7, elevationM: 566, levelM: 41,
                trend24hHm3: 0, outflowM3s: 1.2, transferM3s: 5.7
            ),
            recent: [],
            daily: days,
            weather: Weather(
                observedAt: now, temperatureC: nil, windMs: nil, windDirectionDeg: nil, humidityPct: nil,
                pressureHpa: nil, solarWm2: nil, rain1hMm: nil, rain24hMm: nil
            ),
            weekly: Weekly(
                date: "2026-10-27", volumeHm3: 70, capacityHm3: 138, percent: 50.7, changeHm3: 0,
                lastYearHm3: 75, tenYearAvgHm3: 57.5
            ),
            neighbours: [],
            rainGauges: [],
            sources: []
        )
    }()
}
