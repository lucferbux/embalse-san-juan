import Foundation

/// The three reservoirs of the Alberche chain the app shows, in river order. San Juan is the app's own;
/// Burguillo and Picadas have their own pages in "El río", from 2.0 on.
public enum ReservoirID: String, CaseIterable, Codable, Sendable, Identifiable {
    case burguillo, sanJuan, picadas

    public var id: String { rawValue }

    /// The SAIH station code, as `Snapshot.Neighbour.code` carries it.
    public var stationCode: String {
        switch self {
        case .burguillo: "E_17"
        case .sanJuan: "E_19"
        case .picadas: "E_20"
        }
    }

    public var name: String {
        switch self {
        case .burguillo: "Burguillo"
        case .sanJuan: "San Juan"
        case .picadas: "Picadas"
        }
    }

    /// `public/history` keeps its 1.0 name for San Juan, which the 1.0 apps still read.
    public var historyDocument: String {
        switch self {
        case .sanJuan: "history"
        case .burguillo: "history-burguillo"
        case .picadas: "history-picadas"
        }
    }
}

/// A reservoir's latest SAIH reading, whichever of the three it is.
public struct ReservoirReading: Sendable, Equatable, Identifiable {
    public var reservoir: ReservoirID
    public var observedAt: Date
    public var volumeHm3: Double
    public var percent: Double
    public var id: ReservoirID { reservoir }

    /// Capacity implied by the reading itself, since neighbours carry no capacity of their own.
    public var capacityHm3: Double { percent > 0 ? volumeHm3 / percent * 100 : 0 }
}

public extension Snapshot {
    /// Burguillo, San Juan and Picadas, in river order, skipping any neighbour the backend could not read.
    var chain: [ReservoirReading] {
        ReservoirID.allCases.compactMap { id in
            if id == .sanJuan {
                return ReservoirReading(reservoir: id, observedAt: live.observedAt, volumeHm3: live.volumeHm3, percent: live.percent)
            }
            guard let neighbour = neighbours.first(where: { $0.code == id.stationCode }) else { return nil }
            return ReservoirReading(reservoir: id, observedAt: neighbour.observedAt, volumeHm3: neighbour.volumeHm3, percent: neighbour.percent)
        }
    }

    func reading(of id: ReservoirID) -> ReservoirReading? { chain.first { $0.reservoir == id } }
}
