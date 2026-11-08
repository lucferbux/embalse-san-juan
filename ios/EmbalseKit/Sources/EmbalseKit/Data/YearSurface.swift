import Foundation

/// The last 12 months of SAIH daily volume, ready to draw as the water card's surface (docs/design/review-2.0): one
/// value per sampled day as a fraction of capacity, ending with today's live reading, plus the same days a year
/// earlier and the range of the four years before. SAIH only: MITECO's weekly series never mixes in.
public struct YearSurface: Sendable, Equatable {
    public var start: Date
    public var end: Date
    /// Fractions of capacity, oldest first, the last one today.
    public var levels: [Double]
    /// The same days a year earlier, when the history reaches that far.
    public var lastYear: [Double]?
    /// Lowest and highest of the previous four years for each sampled day, when at least two years are there.
    public var band: [ClosedRange<Double>]?
    /// The highest daily volume in the history, as a fraction of capacity.
    public var record: Double?
    public var recordHm3: Double?
    public var capacityHm3: Double
    /// Volume a year ago, for "6,9 hm³ menos que hace un año".
    public var lastYearHm3: Double?
    public var todayHm3: Double

    /// Days between samples: 365 days drawn every 3 days is plenty for a phone and keeps the path light in widgets.
    static let step = 3

    public init?(history: History, today: ReservoirReading?, capacityHm3: Double, calendar: Calendar = .current) {
        guard capacityHm3 > 0, let lastDay = history.daily.last else { return nil }
        let daily = history.daily.sorted { $0.date < $1.date }
        let endDay = calendar.startOfDay(for: today?.observedAt ?? lastDay.date)
        guard let start = calendar.date(byAdding: .day, value: -364, to: endDay) else { return nil }

        // Last value on or before each day, carried forward over gaps.
        func values(from first: Date) -> [Double?] {
            var result: [Double?] = []
            var index = 0
            var current: Double?
            for offset in stride(from: 0, through: 364, by: Self.step) {
                guard let day = calendar.date(byAdding: .day, value: offset, to: first) else { continue }
                let limit = calendar.date(byAdding: .day, value: 1, to: day) ?? day
                while index < daily.count, daily[index].date < limit {
                    current = daily[index].volumeHm3
                    index += 1
                }
                result.append(current)
            }
            return result
        }

        let thisYear = values(from: start)
        guard thisYear.compactMap({ $0 }).count >= thisYear.count / 2 else { return nil }
        var levels = thisYear.map { ($0 ?? thisYear.compactMap { $0 }.first ?? 0) / capacityHm3 }
        let todayVolume = today?.volumeHm3 ?? lastDay.volumeHm3
        levels.append(todayVolume / capacityHm3)

        func yearsBack(_ years: Int) -> [Double?]? {
            guard let first = calendar.date(byAdding: .day, value: -365 * years, to: start),
                  daily.first.map({ $0.date <= first }) == true else { return nil }
            return values(from: first)
        }
        let previous = yearsBack(1)
        let lastYear = previous.map { $0.map { ($0 ?? 0) / capacityHm3 } }
        let years = (1...4).compactMap(yearsBack)
        var band: [ClosedRange<Double>]?
        if years.count >= 2 {
            band = (0..<thisYear.count).map { index in
                let values = years.compactMap { $0[index] }.map { $0 / capacityHm3 }
                return (values.min() ?? 0)...(values.max() ?? 0)
            }
        }

        let maximum = daily.map(\.volumeHm3).max()
        self.start = start
        self.end = endDay
        self.levels = levels
        self.lastYear = lastYear.map { $0 + [$0.last ?? 0] }
        self.band = band.map { $0 + [$0.last ?? 0...0] }
        self.recordHm3 = maximum
        self.record = maximum.map { $0 / capacityHm3 }
        self.capacityHm3 = capacityHm3
        self.lastYearHm3 = previous?.last.flatMap { $0 }
        self.todayHm3 = todayVolume
    }

    /// The date of the sample at `index`.
    public func date(at index: Int, calendar: Calendar = .current) -> Date {
        index >= levels.count - 1 ? end : calendar.date(byAdding: .day, value: index * Self.step, to: start) ?? start
    }

    /// The change against a year ago, in hm³, when it is known.
    public var changeFromLastYearHm3: Double? { lastYearHm3.map { todayHm3 - $0 } }
}
