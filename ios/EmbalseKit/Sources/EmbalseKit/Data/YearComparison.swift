import Foundation

/// "Este año": this year's MITECO weeks against the same weeks last year and the 10-year average.
///
/// Every line is MITECO's weekly series, never SAIH's daily one, so the three are measured the same way. The rules match
/// the backend's `summarise` (`backend/src/sources/miteco.ts`): a past week counts if it falls within 3 days of the same
/// date in that year, and the average needs all 10 years, as the bulletin's own figure does.
public struct YearComparison: Sendable, Equatable {
    public struct Point: Sendable, Equatable, Identifiable {
        /// The week's date moved into the current year, so the three lines share one axis.
        public var date: Date
        public var volumeHm3: Double
        public var id: Date { date }
    }

    public var year: Int
    public var capacityHm3: Double
    /// From January to the latest bulletin. Its last point is today's weekly figure.
    public var thisYear: [Point]
    /// The whole of last year.
    public var lastYear: [Point]
    /// The whole year, each week averaged over the 10 years before this one. Weeks without all 10 years are left out.
    public var average: [Point]

    /// Three days, plus half a day so a date across a change of time (an hour longer or shorter) still counts.
    static let tolerance: TimeInterval = 3.5 * 86_400
    static let years = 10

    public init?(history: History) {
        guard let latest = history.weekly.last else { return nil }
        let calendar = Self.calendar
        let year = calendar.component(.year, from: latest.date)
        self.year = year
        capacityHm3 = latest.capacityHm3

        let weekly = history.weekly
        func value(near date: Date) -> Double? {
            // The series is sorted, so a binary search finds the closest week.
            var low = 0, high = weekly.count - 1
            while low < high {
                let mid = (low + high) / 2
                if weekly[mid].date < date { low = mid + 1 } else { high = mid }
            }
            let candidates = [low - 1, low].filter { weekly.indices.contains($0) }
            guard let best = candidates.min(by: { abs(weekly[$0].date.timeIntervalSince(date)) < abs(weekly[$1].date.timeIntervalSince(date)) }),
                  abs(weekly[best].date.timeIntervalSince(date)) <= Self.tolerance else { return nil }
            return weekly[best].volumeHm3
        }
        func shifted(_ date: Date, by years: Int) -> Date { calendar.date(byAdding: .year, value: years, to: date) ?? date }

        thisYear = weekly.filter { calendar.component(.year, from: $0.date) == year }.map { Point(date: $0.date, volumeHm3: $0.volumeHm3) }
        let last = weekly.filter { calendar.component(.year, from: $0.date) == year - 1 }
        lastYear = last.map { Point(date: shifted($0.date, by: 1), volumeHm3: $0.volumeHm3) }
        // Last year's weeks give the grid for the whole year; each is averaged over years -1 to -10.
        average = last.compactMap { week in
            let reference = shifted(week.date, by: 1)
            let values = (1...Self.years).compactMap { value(near: shifted(reference, by: -$0)) }
            guard values.count == Self.years else { return nil }
            return Point(date: reference, volumeHm3: values.reduce(0, +) / Double(values.count))
        }
    }

    /// Same week last year, for the latest bulletin.
    public var lastYearNow: Double? { nearest(in: lastYear, to: thisYear.last?.date) }
    /// The 10-year average for the latest bulletin's week.
    public var averageNow: Double? { nearest(in: average, to: thisYear.last?.date) }

    private func nearest(in points: [Point], to date: Date?) -> Double? {
        guard let date else { return nil }
        return points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
            .flatMap { abs($0.date.timeIntervalSince(date)) <= Self.tolerance ? $0.volumeHm3 : nil }
    }

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        return calendar
    }
}
