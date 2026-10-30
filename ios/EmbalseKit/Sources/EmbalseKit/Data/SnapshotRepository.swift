import Foundation

/// Keeps the last good snapshot in the App Group, so the app and widgets share it and work offline.
public struct SnapshotCache: Sendable {
    public static let appGroup = "group.com.lucferbux.embalsesanjuan"

    let fileURL: URL

    public init(directory: URL? = nil) {
        let root = directory
            ?? FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup)
            // Unsigned test builds have no App Group.
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        fileURL = root.appending(path: "snapshot.json")
    }

    public func load() -> Snapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? FirestoreClient.makeDecoder().decode(Snapshot.self, from: data)
    }

    public func save(_ snapshot: Snapshot) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

public struct SnapshotRepository: Sendable {
    public enum Origin: Sendable, Equatable { case network, cache }

    public struct Result: Sendable {
        public var snapshot: Snapshot
        public var origin: Origin
    }

    private let fetch: @Sendable () async throws -> Snapshot
    private let cache: SnapshotCache

    public init(
        fetch: @escaping @Sendable () async throws -> Snapshot = { try await FirestoreClient().fetchSnapshot() },
        cache: SnapshotCache = SnapshotCache()
    ) {
        self.fetch = fetch
        self.cache = cache
    }

    /// Falls back to the last saved snapshot. Only throws when there is nothing to show at all.
    public func load() async throws -> Result {
        do {
            let snapshot = try await fetch()
            cache.save(snapshot)
            return Result(snapshot: snapshot, origin: .network)
        } catch {
            guard let cached = cache.load() else { throw error }
            return Result(snapshot: cached, origin: .cache)
        }
    }

    public func cached() -> Snapshot? {
        cache.load()
    }
}
