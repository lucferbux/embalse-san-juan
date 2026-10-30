import Foundation

/// Reads public documents through Firestore's REST API. Widgets have tight memory limits,
/// so neither they nor the app link the Firebase SDK.
public struct FirestoreClient: Sendable {
    public enum ClientError: Error, Equatable {
        case badStatus(Int)
        case missingPayload
        case unsupportedSchema(Int)
    }

    static let baseURL = URL(string: "https://firestore.googleapis.com/v1/projects/embalse-san-juan/databases/(default)/documents/public")!
    static let supportedSchema = 1

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetchSnapshot() async throws -> Snapshot {
        let snapshot: Snapshot = try await fetch("snapshot")
        guard snapshot.schemaVersion == Self.supportedSchema else {
            throw ClientError.unsupportedSchema(snapshot.schemaVersion)
        }
        return snapshot
    }

    public func fetchHistory() async throws -> History {
        try await fetch("history")
    }

    private func fetch<T: Decodable>(_ document: String) async throws -> T {
        var request = URLRequest(url: Self.baseURL.appending(path: document))
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        let (data, response) = try await session.data(for: request)
        if let status = (response as? HTTPURLResponse)?.statusCode, status != 200 {
            throw ClientError.badStatus(status)
        }
        return try Self.decodePayload(data)
    }

    /// Documents hold the contract JSON in one string field, `payload`.
    static func decodePayload<T: Decodable>(_ data: Data) throws -> T {
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard let payload = envelope.fields?.payload?.stringValue?.data(using: .utf8) else {
            throw ClientError.missingPayload
        }
        return try makeDecoder().decode(T.self, from: payload)
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private struct Envelope: Decodable {
        struct Fields: Decodable {
            struct StringField: Decodable { var stringValue: String? }
            var payload: StringField?
        }
        var fields: Fields?
    }
}
