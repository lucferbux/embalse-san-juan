import Foundation

/// Swift view of `contract/snapshot.schema.json`. Tests decode the same fixture the backend validates.
public struct Snapshot: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    public var generatedAt: Date
    public var reservoir: Reservoir
    public var live: Live
    public var recent: [RecentReading]
    public var daily: [DailyPoint]
    public var weather: Weather
    public var weekly: Weekly
    public var neighbours: [Neighbour]
    public var rainGauges: [RainGauge]
    public var sources: [Source]

    public struct Reservoir: Codable, Sendable, Equatable {
        public var id: String
        public var name: String
        public var river: String
        public var basin: String
        public var province: String
        public var municipality: String
        public var damType: String
        public var yearBuilt: Int
        public var surfaceHa: Double
        public var uses: [String]
    }

    public struct Live: Codable, Sendable, Equatable {
        public var observedAt: Date
        public var volumeHm3: Double
        public var percent: Double
        public var elevationM: Double?
        public var levelM: Double?
        public var trend24hHm3: Double
        public var outflowM3s: Double?
        public var transferM3s: Double?
    }

    public struct RecentReading: Codable, Sendable, Equatable, Identifiable {
        public var at: Date
        public var volumeHm3: Double
        public var percent: Double
        public var outflowM3s: Double?
        public var id: Date { at }
    }

    public struct DailyPoint: Codable, Sendable, Equatable, Identifiable {
        public var date: String
        public var volumeHm3: Double
        public var id: String { date }
        public var day: Date { Day.date(from: date) }
    }

    public struct Weather: Codable, Sendable, Equatable {
        public var observedAt: Date
        public var temperatureC: Double?
        public var windMs: Double?
        public var windDirectionDeg: Double?
        public var humidityPct: Double?
        public var pressureHpa: Double?
        public var solarWm2: Double?
        public var rain1hMm: Double?
        public var rain24hMm: Double?
    }

    public struct Weekly: Codable, Sendable, Equatable {
        public var date: String
        public var volumeHm3: Double
        public var capacityHm3: Double
        public var percent: Double
        public var changeHm3: Double
        public var lastYearHm3: Double?
        public var tenYearAvgHm3: Double?
        public var day: Date { Day.date(from: date) }
    }

    public struct Neighbour: Codable, Sendable, Equatable, Identifiable {
        public enum Position: String, Codable, Sendable { case upstream, downstream }
        public var code: String
        public var name: String
        public var position: Position
        public var observedAt: Date
        public var volumeHm3: Double
        public var percent: Double
        public var id: String { code }
    }

    public struct RainGauge: Codable, Sendable, Equatable, Identifiable {
        public var code: String
        public var name: String
        public var observedAt: Date
        public var rain1hMm: Double?
        public var rain24hMm: Double?
        public var id: String { code }
    }

    public struct Source: Codable, Sendable, Equatable, Identifiable {
        public var name: String
        public var publisher: String
        public var url: String
        public var note: String
        public var id: String { name }
    }
}

public extension Snapshot {
    /// Readings are hourly, so 6 hours without one means collection is failing.
    static let staleAfter: TimeInterval = 6 * 3600

    func isStale(at now: Date = .now) -> Bool {
        now.timeIntervalSince(live.observedAt) > Self.staleAfter
    }

    var last7Days: [DailyPoint] { Array(daily.suffix(7)) }
}

/// Payload of `public/history`, sent as compact rows to keep the document small.
public struct History: Decodable, Sendable, Equatable {
    public struct WeeklyPoint: Sendable, Equatable, Identifiable {
        public var date: Date
        public var volumeHm3: Double
        public var capacityHm3: Double
        public var id: Date { date }
    }

    public struct DailyPoint: Sendable, Equatable, Identifiable {
        public var date: Date
        public var volumeHm3: Double
        public var id: Date { date }
    }

    public var generatedAt: Date
    public var weekly: [WeeklyPoint]
    public var daily: [DailyPoint]

    private enum CodingKeys: String, CodingKey { case generatedAt, weekly, daily }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)

        var weeklyRows = try container.nestedUnkeyedContainer(forKey: .weekly)
        var weekly: [WeeklyPoint] = []
        while !weeklyRows.isAtEnd {
            var row = try weeklyRows.nestedUnkeyedContainer()
            weekly.append(WeeklyPoint(
                date: Day.date(from: try row.decode(String.self)),
                volumeHm3: try row.decode(Double.self),
                capacityHm3: try row.decode(Double.self)
            ))
        }
        self.weekly = weekly

        var dailyRows = try container.nestedUnkeyedContainer(forKey: .daily)
        var daily: [DailyPoint] = []
        while !dailyRows.isAtEnd {
            var row = try dailyRows.nestedUnkeyedContainer()
            daily.append(DailyPoint(
                date: Day.date(from: try row.decode(String.self)),
                volumeHm3: try row.decode(Double.self)
            ))
        }
        self.daily = daily
    }
}

/// Calendar days from the backend are Madrid days, kept at midday so no time zone moves them.
enum Day {
    static func date(from text: String) -> Date {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return .distantPast }
        var components = DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)
        components.timeZone = TimeZone(identifier: "Europe/Madrid")
        return Calendar(identifier: .gregorian).date(from: components) ?? .distantPast
    }
}
