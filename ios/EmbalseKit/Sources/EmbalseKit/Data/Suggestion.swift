import Foundation

/// A suggestion sent from the app. It's anonymous and holds only what the user wrote: the limits here
/// mirror the checks in firebase/firestore.rules.
public struct Suggestion: Sendable, Equatable {
    public enum Kind: String, CaseIterable, Sendable, Identifiable {
        case suggestion, bug, other

        public var id: Self { self }

        public var label: String {
            switch self {
            case .suggestion: "Sugerencia"
            case .bug: "Algo no funciona"
            case .other: "Otra cosa"
            }
        }
    }

    public static let minimumLength = 3
    public static let maximumLength = 1000

    public var kind: Kind
    public var text: String

    public init(kind: Kind, text: String) {
        self.kind = kind
        self.text = text
    }

    public var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var isValid: Bool {
        (Self.minimumLength...Self.maximumLength).contains(trimmedText.count)
    }

    /// Firestore's REST format for a new document.
    func firestoreBody(date: Date, appVersion: String) throws -> Data {
        let fields: [String: [String: String]] = [
            "kind": ["stringValue": kind.rawValue],
            "text": ["stringValue": trimmedText],
            "appVersion": ["stringValue": appVersion],
            "createdAt": ["timestampValue": date.formatted(.iso8601)],
        ]
        return try JSONEncoder().encode(["fields": fields])
    }
}

public struct SuggestionClient: Sendable {
    public enum ClientError: Error, Equatable {
        case invalid
        case badStatus(Int)
    }

    private static let url = URL(string: "https://firestore.googleapis.com/v1/projects/embalse-san-juan/databases/(default)/documents/suggestions")!

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ suggestion: Suggestion) async throws {
        guard suggestion.isValid else { throw ClientError.invalid }
        var request = URLRequest(url: Self.url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        request.httpBody = try suggestion.firestoreBody(date: .now, appVersion: version)
        let (_, response) = try await session.data(for: request)
        if let status = (response as? HTTPURLResponse)?.statusCode, status != 200 {
            throw ClientError.badStatus(status)
        }
    }
}
