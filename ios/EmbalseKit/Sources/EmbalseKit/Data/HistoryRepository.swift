import Foundation

/// Fetches a reservoir's history and keeps the last good copy in the App Group, so "Este año" and the
/// reservoir pages work offline. The documents are large and change at most hourly, so a fresh copy is reused.
public struct HistoryRepository: Sendable {
    private let fetch: @Sendable (ReservoirID) async throws -> Data
    private let directory: URL

    /// New days land once a day and new weeks once a week, so an hour-old copy is as good as a new one.
    static let freshFor: TimeInterval = 3600

    public init(
        fetch: @escaping @Sendable (ReservoirID) async throws -> Data = { try await FirestoreClient().fetchDocument($0.historyDocument) },
        directory: URL? = nil
    ) {
        self.fetch = fetch
        self.directory = directory ?? SnapshotCache().fileURL.deletingLastPathComponent()
    }

    private func fileURL(_ id: ReservoirID) -> URL { directory.appending(path: "\(id.historyDocument).json") }

    public func cached(_ id: ReservoirID) -> History? {
        guard let data = try? Data(contentsOf: fileURL(id)) else { return nil }
        return try? FirestoreClient.decodePayload(data)
    }

    /// The cached copy if it is fresh, otherwise the network, falling back to any cached copy offline.
    public func load(_ id: ReservoirID, now: Date = .now) async throws -> History {
        let url = fileURL(id)
        if let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
           now.timeIntervalSince(modified) < Self.freshFor, let cached = cached(id) {
            return cached
        }
        do {
            let data = try await fetch(id)
            let history: History = try FirestoreClient.decodePayload(data)
            try? data.write(to: url, options: .atomic)
            return history
        } catch {
            guard let cached = cached(id) else { throw error }
            return cached
        }
    }
}
